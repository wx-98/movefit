import HealthKit
import XCTest
@testable import MoveFit

final class HealthKitAdapterTests: XCTestCase {
    func testMakeSleepSegmentMapsCategoryValuesToStages() throws {
        let adapter = makeAdapter()
        let sleepType = try XCTUnwrap(HKObjectType.categoryType(forIdentifier: .sleepAnalysis))
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let mappings: [(value: Int, stage: SleepStage)] = [
            (0, .inBed), (1, .asleep), (2, .awake), (3, .core), (4, .deep), (5, .rem)
        ]
        for mapping in mappings {
            let sample = HKCategorySample(
                type: sleepType,
                value: mapping.value,
                start: start,
                end: start.addingTimeInterval(600)
            )
            let segment = try XCTUnwrap(adapter.makeSleepSegment(from: sample), "值 \(mapping.value) 应映射成功")
            XCTAssertEqual(segment.stage, mapping.stage)
            XCTAssertEqual(segment.startDate, start)
            XCTAssertEqual(segment.endDate, start.addingTimeInterval(600))
        }
    }

    func testMakeSleepSessionsGroupsSegmentsWithinFourHours() throws {
        let calendar = try utcCalendar()
        let firstNight = try [
            makeSegment(calendar: calendar, day: 25, hour: 23, minute: 0),
            makeSegment(calendar: calendar, day: 26, hour: 0, minute: 30)
        ]
        let secondNight = try [
            makeSegment(calendar: calendar, day: 26, hour: 23, minute: 0)
        ]
        let sessions = adapter(for: calendar).makeSleepSessions(from: firstNight + secondNight)
        XCTAssertEqual(sessions.count, 2, "间隔超过 4 小时的分段应归为不同睡眠会话")
        XCTAssertEqual(sessions[0].count, 2)
        XCTAssertEqual(sessions[1].count, 1)
    }

    func testMakeSleepSessionsSortsSegmentsByStartDate() throws {
        let calendar = try utcCalendar()
        let earlier = try [makeSegment(calendar: calendar, day: 25, hour: 23, minute: 0)]
        let later = try [makeSegment(calendar: calendar, day: 26, hour: 0, minute: 30)]
        let sessions = adapter(for: calendar).makeSleepSessions(from: later + earlier)
        XCTAssertEqual(sessions.count, 1, "乱序输入应先排序再归组")
        XCTAssertEqual(sessions[0].count, 2)
    }

    func testBedtimeDeviationAveragesPriorSessionBedtimes() throws {
        let calendar = try utcCalendar()
        let sessions = try [
            [makeSegment(calendar: calendar, day: 24, hour: 23, minute: 0)],
            [makeSegment(calendar: calendar, day: 25, hour: 23, minute: 30)]
        ]
        XCTAssertEqual(adapter(for: calendar).bedtimeDeviation(for: sessions), 30)
    }

    func testBedtimeDeviationHandlesMidnightWrap() throws {
        let calendar = try utcCalendar()
        let sessions = try [
            [makeSegment(calendar: calendar, day: 24, hour: 23, minute: 50)],
            [makeSegment(calendar: calendar, day: 25, hour: 0, minute: 10)]
        ]
        XCTAssertEqual(
            adapter(for: calendar).bedtimeDeviation(for: sessions),
            20,
            "跨午夜的偏差应取环形的较短方向"
        )
    }

    func testBedtimeDeviationRequiresMultipleSessions() throws {
        let calendar = try utcCalendar()
        let sessions = try [
            [makeSegment(calendar: calendar, day: 24, hour: 23, minute: 0)]
        ]
        XCTAssertNil(adapter(for: calendar).bedtimeDeviation(for: sessions))
    }

    func testMapWorkoutTypeCoversSupportedActivities() {
        let mappings: [(HKWorkoutActivityType, WorkoutType)] = [
            (.running, .running),
            (.walking, .walking),
            (.cycling, .cycling),
            (.yoga, .yoga),
            (.traditionalStrengthTraining, .strength),
            (.functionalStrengthTraining, .strength),
            (.highIntensityIntervalTraining, .hiit),
            (.hiking, .hiking),
            (.swimming, .swimming),
            (.elliptical, .elliptical),
            (.rowing, .rowing),
            (.pilates, .pilates),
            (.badminton, .other)
        ]
        for (activityType, expected) in mappings {
            XCTAssertEqual(HealthKitAdapter.mapWorkoutType(activityType), expected)
        }
    }

    private func makeAdapter(calendar: Calendar = .autoupdatingCurrent) -> HealthKitAdapter {
        HealthKitAdapter(store: HKHealthStore(), calendar: calendar, now: { Date(timeIntervalSinceReferenceDate: 0) })
    }

    private func adapter(for calendar: Calendar) -> HealthKitAdapter {
        makeAdapter(calendar: calendar)
    }

    private func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        return calendar
    }

    private func makeSegment(calendar: Calendar, day: Int, hour: Int, minute: Int) throws -> SleepStageSegment {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: day,
            hour: hour,
            minute: minute
        )))
        return SleepStageSegment(id: UUID(), startDate: start, endDate: start.addingTimeInterval(1_800), stage: .core)
    }
}
