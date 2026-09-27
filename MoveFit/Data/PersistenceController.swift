import CoreData
import CoreLocation

final class PersistenceController: PersonalHealthRecordProviding {
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MoveFit", managedObjectModel: Self.makeModel())
        container.persistentStoreDescriptions.forEach {
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
        if inMemory {
            container.persistentStoreDescriptions.first?.type = NSInMemoryStoreType
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                assertionFailure("无法加载本地数据库：\(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func loadProfile() async throws -> UserProfile? {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ProfileRecord")
            request.fetchLimit = 1
            guard let record = try context.fetch(request).first,
                  let nickname = record.value(forKey: "nickname") as? String else { return nil }
            return UserProfile(
                nickname: nickname,
                height: Measurement(
                    value: record.value(forKey: "heightCentimeters") as? Double ?? 0,
                    unit: .centimeters
                ),
                weight: Measurement(
                    value: record.value(forKey: "weightKilograms") as? Double ?? 0,
                    unit: .kilograms
                ),
                bodyFatPercentage: record.value(forKey: "bodyFatPercentage") as? Double ?? 0
            )
        }
    }

    func save(profile: UserProfile) async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "ProfileRecord")
            request.fetchLimit = 1
            let record = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: "ProfileRecord", into: context)
            record.setValue(profile.nickname, forKey: "nickname")
            record.setValue(profile.height.converted(to: .centimeters).value, forKey: "heightCentimeters")
            record.setValue(profile.weight.converted(to: .kilograms).value, forKey: "weightKilograms")
            record.setValue(profile.bodyFatPercentage, forKey: "bodyFatPercentage")
            try context.save()
        }
    }

    func loadJoinedChallengeIDs() async throws -> Set<UUID> {
        try await loadEnabledIDs(entityName: "ChallengeStateRecord", stateKey: "isJoined")
    }

    func saveChallenge(id: UUID, isJoined: Bool) async throws {
        try await saveState(
            entityName: "ChallengeStateRecord",
            id: id,
            stateKey: "isJoined",
            value: isJoined
        )
    }

    func loadFavoriteArticleIDs() async throws -> Set<UUID> {
        try await loadEnabledIDs(entityName: "ArticleStateRecord", stateKey: "isFavorite")
    }

    func saveArticle(id: UUID, isFavorite: Bool) async throws {
        try await saveState(
            entityName: "ArticleStateRecord",
            id: id,
            stateKey: "isFavorite",
            value: isFavorite
        )
    }

    func personalHealthRecords() async throws -> [PersonalHealthRecord] {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalHealthRecordEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "occurredAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.makePersonalHealthRecord)
        }
    }

    func savePersonalHealthRecord(_ healthRecord: PersonalHealthRecord) async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalHealthRecordEntity")
            request.predicate = NSPredicate(format: "id == %@", healthRecord.id as CVarArg)
            request.fetchLimit = 1
            let record = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: "PersonalHealthRecordEntity", into: context)
            record.setValue(healthRecord.id, forKey: "id")
            record.setValue(healthRecord.category.rawValue, forKey: "category")
            record.setValue(healthRecord.occurredAt, forKey: "occurredAt")
            record.setValue(healthRecord.title, forKey: "title")
            record.setValue(healthRecord.detail, forKey: "detail")
            record.setValue(healthRecord.primaryValue, forKey: "primaryValue")
            record.setValue(healthRecord.secondaryValue, forKey: "secondaryValue")
            record.setValue(healthRecord.tertiaryValue, forKey: "tertiaryValue")
            record.setValue(healthRecord.isCompleted, forKey: "isCompleted")
            try context.save()
        }
    }

    func deletePersonalHealthRecord(id: UUID) async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "PersonalHealthRecordEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            try context.fetch(request).forEach(context.delete)
            try context.save()
        }
    }

    func loadPreference(key: String) async throws -> Bool? {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "AppPreferenceRecord")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.fetchLimit = 1
            return try context.fetch(request).first?.value(forKey: "boolValue") as? Bool
        }
    }

    func savePreference(key: String, value: Bool) async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "AppPreferenceRecord")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.fetchLimit = 1
            let record = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: "AppPreferenceRecord", into: context)
            record.setValue(key, forKey: "key")
            record.setValue(value, forKey: "boolValue")
            try context.save()
        }
    }

    func loadStringPreference(key: String) async throws -> String? {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "AppPreferenceRecord")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.fetchLimit = 1
            return try context.fetch(request).first?.value(forKey: "stringValue") as? String
        }
    }

    func saveStringPreference(key: String, value: String) async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "AppPreferenceRecord")
            request.predicate = NSPredicate(format: "key == %@", key)
            request.fetchLimit = 1
            let record = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: "AppPreferenceRecord", into: context)
            record.setValue(key, forKey: "key")
            record.setValue(value, forKey: "stringValue")
            try context.save()
        }
    }

    func loadWorkouts() async throws -> [WorkoutRecord] {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutRecordEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.makeWorkout)
        }
    }

    func save(workout: WorkoutRecord, operationID: UUID) async throws {
        try await perform { context in
            let operationRequest = NSFetchRequest<NSManagedObject>(entityName: "OfflineOperationRecord")
            operationRequest.predicate = NSPredicate(format: "id == %@", operationID as CVarArg)
            operationRequest.fetchLimit = 1
            guard try context.fetch(operationRequest).isEmpty else { return }

            let workoutRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkoutRecordEntity")
            workoutRequest.predicate = NSPredicate(format: "id == %@", workout.id as CVarArg)
            workoutRequest.fetchLimit = 1
            if try context.fetch(workoutRequest).isEmpty {
                let record = NSEntityDescription.insertNewObject(forEntityName: "WorkoutRecordEntity", into: context)
                record.setValue(workout.id, forKey: "id")
                record.setValue(workout.type.rawValue, forKey: "type")
                record.setValue(workout.startedAt, forKey: "startedAt")
                record.setValue(workout.duration, forKey: "duration")
                record.setValue(workout.distance?.converted(to: .meters).value, forKey: "distanceMeters")
                record.setValue(workout.energy?.converted(to: .kilocalories).value, forKey: "energyKilocalories")
                record.setValue(Self.encodeRoute(workout.route), forKey: "routeData")
            }

            let operation = NSEntityDescription.insertNewObject(forEntityName: "OfflineOperationRecord", into: context)
            operation.setValue(operationID, forKey: "id")
            operation.setValue("saveWorkout", forKey: "kind")
            operation.setValue(Date(), forKey: "createdAt")
            try context.save()
        }
    }

    func offlineOperationCount() async throws -> Int {
        try await perform { context in
            try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "OfflineOperationRecord"))
        }
    }

    func clearRebuildableCache() async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "OfflineOperationRecord")
            try context.fetch(request).forEach(context.delete)
            try context.save()
        }
    }

    private func perform<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.viewContext
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    continuation.resume(returning: try operation(context))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadEnabledIDs(entityName: String, stateKey: String) async throws -> Set<UUID> {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "%K == YES", stateKey)
            return Set(try context.fetch(request).compactMap { $0.value(forKey: "id") as? UUID })
        }
    }

    private func saveState(
        entityName: String,
        id: UUID,
        stateKey: String,
        value: Bool
    ) async throws {
        try await perform { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let record = try context.fetch(request).first
                ?? NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
            record.setValue(id, forKey: "id")
            record.setValue(value, forKey: stateKey)
            try context.save()
        }
    }

    private static func makeWorkout(from record: NSManagedObject) -> WorkoutRecord? {
        guard let id = record.value(forKey: "id") as? UUID,
              let typeName = record.value(forKey: "type") as? String,
              let type = WorkoutType(rawValue: typeName),
              let startedAt = record.value(forKey: "startedAt") as? Date else { return nil }
        let distance = (record.value(forKey: "distanceMeters") as? Double).map {
            Measurement(value: $0, unit: UnitLength.meters)
        }
        let energy = (record.value(forKey: "energyKilocalories") as? Double).map {
            Measurement(value: $0, unit: UnitEnergy.kilocalories)
        }
        return WorkoutRecord(
            id: id,
            type: type,
            startedAt: startedAt,
            duration: record.value(forKey: "duration") as? Double ?? 0,
            distance: distance,
            energy: energy,
            route: decodeRoute(record.value(forKey: "routeData") as? Data)
        )
    }

    private static func makePersonalHealthRecord(from record: NSManagedObject) -> PersonalHealthRecord? {
        guard let id = record.value(forKey: "id") as? UUID,
              let categoryName = record.value(forKey: "category") as? String,
              let category = PersonalHealthCategory(rawValue: categoryName),
              let occurredAt = record.value(forKey: "occurredAt") as? Date,
              let title = record.value(forKey: "title") as? String,
              let detail = record.value(forKey: "detail") as? String else { return nil }
        return PersonalHealthRecord(
            id: id,
            category: category,
            occurredAt: occurredAt,
            title: title,
            detail: detail,
            primaryValue: record.value(forKey: "primaryValue") as? Double,
            secondaryValue: record.value(forKey: "secondaryValue") as? Double,
            tertiaryValue: record.value(forKey: "tertiaryValue") as? Double,
            isCompleted: record.value(forKey: "isCompleted") as? Bool ?? false
        )
    }

    private static func encodeRoute(_ route: [CLLocationCoordinate2D]) -> Data? {
        let values = route.flatMap { [$0.latitude, $0.longitude] }
        return try? JSONEncoder().encode(values)
    }

    private static func decodeRoute(_ data: Data?) -> [CLLocationCoordinate2D] {
        guard let data = data,
              let values = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return stride(from: 0, to: values.count - 1, by: 2).map {
            CLLocationCoordinate2D(latitude: values[$0], longitude: values[$0 + 1])
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeEntity(name: "OfflineOperationRecord", attributes: [
                makeAttribute(name: "id", type: .UUIDAttributeType, optional: false),
                makeAttribute(name: "kind", type: .stringAttributeType, optional: false),
                makeAttribute(name: "createdAt", type: .dateAttributeType, optional: false)
            ]),
            makeEntity(name: "ProfileRecord", attributes: [
                makeAttribute(name: "nickname", type: .stringAttributeType, optional: false),
                makeAttribute(name: "heightCentimeters", type: .doubleAttributeType, optional: false),
                makeAttribute(name: "weightKilograms", type: .doubleAttributeType, optional: false),
                makeAttribute(name: "bodyFatPercentage", type: .doubleAttributeType, optional: false)
            ]),
            makeEntity(name: "WorkoutRecordEntity", attributes: [
                makeAttribute(name: "id", type: .UUIDAttributeType, optional: false),
                makeAttribute(name: "type", type: .stringAttributeType, optional: false),
                makeAttribute(name: "startedAt", type: .dateAttributeType, optional: false),
                makeAttribute(name: "duration", type: .doubleAttributeType, optional: false),
                makeAttribute(name: "distanceMeters", type: .doubleAttributeType, optional: true),
                makeAttribute(name: "energyKilocalories", type: .doubleAttributeType, optional: true),
                makeAttribute(name: "routeData", type: .binaryDataAttributeType, optional: true)
            ]),
            makeEntity(name: "ChallengeStateRecord", attributes: [
                makeAttribute(name: "id", type: .UUIDAttributeType, optional: false),
                makeAttribute(name: "isJoined", type: .booleanAttributeType, optional: false)
            ]),
            makeEntity(name: "ArticleStateRecord", attributes: [
                makeAttribute(name: "id", type: .UUIDAttributeType, optional: false),
                makeAttribute(name: "isFavorite", type: .booleanAttributeType, optional: false)
            ]),
            makeEntity(name: "AppPreferenceRecord", attributes: [
                makeAttribute(name: "key", type: .stringAttributeType, optional: false),
                makeAttribute(name: "boolValue", type: .booleanAttributeType, optional: true),
                makeAttribute(name: "stringValue", type: .stringAttributeType, optional: true)
            ]),
            makeEntity(name: "PersonalHealthRecordEntity", attributes: [
                makeAttribute(name: "id", type: .UUIDAttributeType, optional: false),
                makeAttribute(name: "category", type: .stringAttributeType, optional: false),
                makeAttribute(name: "occurredAt", type: .dateAttributeType, optional: false),
                makeAttribute(name: "title", type: .stringAttributeType, optional: false),
                makeAttribute(name: "detail", type: .stringAttributeType, optional: false),
                makeAttribute(name: "primaryValue", type: .doubleAttributeType, optional: true),
                makeAttribute(name: "secondaryValue", type: .doubleAttributeType, optional: true),
                makeAttribute(name: "tertiaryValue", type: .doubleAttributeType, optional: true),
                makeAttribute(name: "isCompleted", type: .booleanAttributeType, optional: false)
            ])
        ]
        return model
    }

    private static func makeEntity(name: String, attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = attributes
        return entity
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
