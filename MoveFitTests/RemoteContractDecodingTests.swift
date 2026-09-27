import XCTest
@testable import MoveFit

final class RemoteContractDecodingTests: XCTestCase {
    func testSocialIdentityDecodesMaskedHintWithoutSubject() throws {
        let list = try decode(
            SocialIdentityDTO.List.self,
            #"{"items":[{"provider":"apple","masked_hint":null,"linked_at":"2026-08-08T08:00:00Z"},{"provider":"wechat","masked_hint":"wx***","linked_at":"2026-08-08T08:00:00Z"},{"provider":"google","masked_hint":"g***@example.test","linked_at":"2026-08-08T08:00:00Z"}]}"#
        )

        let identities = try list.items.map { try $0.domain() }
        XCTAssertEqual(identities.map(\.provider), [.apple, .wechat, .google])
        let identity = try XCTUnwrap(identities.last)
        XCTAssertEqual(identity.provider, .google)
        XCTAssertEqual(identity.maskedHint, "g***@example.test")
    }

    func testGoogleHandoffAndCompletionUsePKCEWireNames() throws {
        let handoff = try decode(
            SocialIdentityDTO.GoogleHandoff.self,
            #"{"authorization_url":"https://accounts.google.test/auth?state=fictional","state":"fictional-state","expires_at":"2026-08-09T10:05:00Z"}"#
        )
        XCTAssertEqual(try handoff.domain().authorizationURL.host, "accounts.google.test")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let request = SocialIdentityDTO.GoogleCompletionRequest(
            authorizationCode: "fictional-one-time-code",
            state: "fictional-state",
            codeVerifier: String(repeating: "a", count: 43),
            redirectURI: "com.movefit.mobile:/oauth2redirect",
            deviceID: "fictional-installation"
        )
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(request)) as? [String: String])
        XCTAssertEqual(payload["code_verifier"], String(repeating: "a", count: 43))
        XCTAssertEqual(payload["redirect_uri"], "com.movefit.mobile:/oauth2redirect")
        XCTAssertEqual(payload["device_id"], "fictional-installation")
    }

    func testChallengeAndLeaderboardDecodePrivacySafeFields() throws {
        let challenge = try decode(
            RemoteChallengeDTO.Item.self,
            #"{"challenge_id":"c7000000-0000-4000-8000-000000000001","title":"Fictional challenge","summary":"Test only","metric":"distance","goal_value":10000,"goal_unit":"meters","starts_at":"2026-08-01T00:00:00Z","ends_at":"2026-08-31T00:00:00Z","enrollment_opens_at":"2026-07-25T00:00:00Z","enrollment_closes_at":"2026-08-15T00:00:00Z","exit_closes_at":null,"eligible_workout_types":["running"],"eligible_workout_sources":["movefit_recorded"],"rule_version":1}"#
        )
        XCTAssertEqual(try challenge.domain().goalUnit, "meters")

        let leaderboard = try decode(
            RemoteChallengeDTO.Leaderboard.self,
            #"{"snapshot_generated_at":"2026-08-08T12:00:00Z","items":[{"rank":1,"display_alias":"Mover-ABCDEF123456","progress_value":8200,"goal_unit":"meters","is_current_user":false}],"next_cursor":null,"has_more":false}"#
        )
        let entry = try XCTUnwrap(leaderboard.domain().entries.first)
        XCTAssertEqual(entry.displayAlias, "Mover-ABCDEF123456")
        XCTAssertFalse(entry.isCurrentUser)

        let participation = try decode(
            RemoteChallengeDTO.Participation.self,
            #"{"participation_id":"c7000000-0000-4000-8000-000000000002","challenge_id":"c7000000-0000-4000-8000-000000000001","status":"active","progress_value":8200,"goal_value":10000,"goal_unit":"meters","is_complete":false,"calculated_at":"2026-08-08T12:00:00Z"}"#
        )
        XCTAssertEqual(try participation.domain().progressValue, 8200)
    }

    func testArticleAndHelpDecodePublishedContent() throws {
        let article = try decode(
            RemoteContentDTO.Article.self,
            ###"{"article_id":"a7000000-0000-4000-8000-000000000001","title":"Fictional article","summary":"Test only","category":"recovery","locale":"en","body_markdown":"## Test","disclaimer":null,"revision":2,"published_at":"2026-08-08T09:00:00Z","updated_at":"2026-08-08T09:30:00Z"}"###
        )
        XCTAssertEqual(try article.domain().revision, 2)

        let help = try decode(
            RemoteContentDTO.HelpArticle.self,
            ###"{"help_article_id":"b7000000-0000-4000-8000-000000000001","title":"Fictional help","category":"workouts","locale":"en","body_markdown":"## Test","revision":1,"updated_at":"2026-08-08T08:15:00Z"}"###
        )
        XCTAssertEqual(try help.domain().category, "workouts")

        let favorite = try decode(
            RemoteContentDTO.Favorite.self,
            #"{"article_id":"a7000000-0000-4000-8000-000000000001","is_favorite":true,"version":1,"updated_at":"2026-08-08T10:00:00Z"}"#
        )
        XCTAssertTrue(try favorite.domain().isFavorite)
    }

    func testSupportTicketSeparatesPrivateMessageFromSummary() throws {
        let created = try decode(
            RemoteSupportDTO.Created.self,
            #"{"ticket":{"ticket_id":"d7000000-0000-4000-8000-000000000001","category":"technical","subject":"Fictional issue","status":"open","version":1,"created_at":"2026-08-08T11:00:00Z","updated_at":"2026-08-08T11:00:00Z","closed_at":null},"first_message":{"message_id":"d7000000-0000-4000-8000-000000000002","sequence":1,"author_role":"user","body":"fictional private body","created_at":"2026-08-08T11:00:00Z"}}"#
        )
        let detail = try created.domain()
        XCTAssertEqual(detail.ticket.status, "open")
        XCTAssertEqual(detail.messages.first?.body, "fictional private body")
    }

    func testRemoteProblemMapperDropsProviderDiagnostic() {
        let error = BackendError.server(
            status: 503,
            code: "social_provider_unavailable",
            message: "private provider diagnostic",
            retryAfterSeconds: nil
        )
        let mapped = RemoteServiceError.map(error)
        XCTAssertEqual(mapped, .server(status: 503, code: "social_provider_unavailable", retryAfterSeconds: nil))
        XCTAssertFalse(String(describing: mapped).contains("private provider diagnostic"))
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: Data(json.utf8))
    }
}
