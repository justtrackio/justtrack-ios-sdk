import Foundation
import SQLite3

final class DefaultSqliteDriver: SqliteDriver {
	enum Const {
		static let eventsTableName = "Events"
		static let messagesTableName = "Messages"
		static let metricsTableName = "Metrics"

		static let maxRetentionTime: TimeInterval = 3 * 24 * 3600

		static let databaseName = "JustTrackSDK_DefaultSqliteDriver_Database"
		static let v2Suffix = "_V2"
	}

	private var db: OpaquePointer?
	private let queue: DispatchQueue

	private let isoFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()

	init(
		databaseName: String = Const.databaseName,
		queue: DispatchQueue = DispatchQueue(label: "io.justtrack.JustTrackSDK.DefaultSqliteDriver.queue", qos: .userInteractive),
		isDebugBuild: Bool = {
			#if DEBUG
				return true
			#else
				return false
			#endif
		}()
	) throws {
		self.queue = queue

		let fileManager = FileManager.default
		let documentsDirectory = try fileManager.url(
			for: .documentDirectory,
			in: .userDomainMask,
			appropriateFor: nil,
			create: true
		)

		let databaseUrl = documentsDirectory.appendingPathComponent("\(databaseName).sqlite")
		let databaseV2Url = documentsDirectory.appendingPathComponent("\(databaseName)\(Const.v2Suffix).sqlite")

		if fileManager.fileExists(atPath: databaseUrl.path) && !fileManager.fileExists(atPath: databaseV2Url.path) {
			try fileManager.copyItem(at: databaseUrl, to: databaseV2Url)
		}

		try openDatabase(url: databaseV2Url)
		let version = try getCurrentVersion()

		// 5.0.1 does not support any version higher than 1
		if version > 1 {
			try closeDatabase()

			if isDebugBuild {
				fatalError(
					"JustTrackSdk: Backward compatibility is not supported. This is a fatal error in DEBUG mode. In RELEASE, the SDK does not generate a fatal error, but it creates a completely new database and discards all the events and logs that were stored by any SDK version higher than 5.0.1."
				)
			} else {
				try fileManager.removeItem(at: databaseV2Url)
				try openDatabase(url: databaseV2Url)
				NSLog("JustTrackSdk: Backward compatibility is not supported. The SDK created a new database.")
			}
		}

		try createEventsTableIfNeeded()
		try createMessagesTableIfNeeded()
		try createMetricsTableIfNeeded()
		try checkAndPerformMigrations()
	}

	deinit {
		queue.async { [weak self] in
			try? self?.closeDatabase()
		}
	}

	func fetchEvents() throws -> [StorableEvent] {
		try queue.sync {
			try self.selectEvents()
		}
	}

	func fetchNextBlockOfMessagesAndMetrics(
		blockSize: Int,
		onReadLogMessage: (StoredLogMessage) -> Void,
		onReadLogMetric: (StoredLogMetric) -> Void
	) throws {
		try queue.sync {
			let (messages, messagesToDelete) = try selectMessages(blockSize: blockSize)
			let (metrics, metricsToDelete) = try selectMetrics(blockSize: blockSize)

			try deleteMessagesAndMetrics(messageIds: messagesToDelete.map { $0.id }, metricIds: metricsToDelete.map { $0.id })

			for message in messages {
				onReadLogMessage(message)
			}

			for metric in metrics {
				onReadLogMetric(metric)
			}
		}
	}

	func removeEvents(
		eventIds: [Int]
	) throws {
		try queue.sync {
			try self.deleteEvents(eventIds: eventIds)
		}
	}

	func removeMessagesAndMetrics(
		messageIds: [Int],
		metricIds: [Int]
	) throws {
		try queue.sync {
			try self.deleteMessagesAndMetrics(messageIds: messageIds, metricIds: metricIds)
		}
	}

	func storeEvent(
		_ event: StorableEvent
	) throws {
		try queue.sync {
			try self.insertEvent(event)
		}
	}

	func storeMessage(
		_ message: StoredLogMessage
	) throws {
		try queue.sync {
			try self.insertMessage(message)
		}
	}

	func storeMetric(
		_ metric: StoredLogMetric
	) throws {
		try queue.sync {
			try self.insertMetric(metric)
		}
	}

	private func checkAndPerformMigrations() throws {
		let currentVersion = try getCurrentVersion()

		if currentVersion == 0 {
			try performMigrationToVersion1()
		}
	}

	private func getCurrentVersion() throws -> Int {
		let versionCommand = "PRAGMA user_version;"
		var versionStatement = try Statement(db: db, command: versionCommand, errorProvider: { DefaultSqliteDriverError.fetching($0) })

		var version = 0

		try versionStatement.fetch { row in
			version = row.integer()
		}

		try versionStatement.finalize()

		return Int(version)
	}

	private func updateVersion(to newVersion: Int) throws {
		let updateVersionCommand = "PRAGMA user_version = \(newVersion);"

		var updateVersionStatement = try Statement(db: db, command: updateVersionCommand, errorProvider: { DefaultSqliteDriverError.tableCreation($0) })

		try updateVersionStatement.execute()
		try updateVersionStatement.finalize()
	}

	private func performMigrationToVersion1() throws {
		if try columnExists(columnName: "SdkVersion", tableName: Const.eventsTableName) {
			try updateVersion(to: 1)
			return
		}

		try executeStatement("BEGIN TRANSACTION;")

		do {
			let deleteCommand = "DELETE FROM \(Const.eventsTableName);"
			try executeStatement(deleteCommand)

			let alterTableCommand = "ALTER TABLE \(Const.eventsTableName) ADD COLUMN SdkVersion TEXT DEFAULT NULL;"
			try executeStatement(alterTableCommand)

			try executeStatement("COMMIT;")
		} catch {
			try? executeStatement("ROLLBACK;")
			throw error
		}

		try updateVersion(to: 1)
	}

	private func executeStatement(_ sql: String) throws {
		var statement = try Statement(db: db, command: sql, errorProvider: { DefaultSqliteDriverError.tableCreation($0) })
		try statement.execute()
		try statement.finalize()
	}

	private func columnExists(columnName: String, tableName: String) throws -> Bool {
		let query = "PRAGMA table_info(\(tableName));"
		var queryStatement = try Statement(db: db, command: query, errorProvider: { DefaultSqliteDriverError.fetching($0) })

		var columnExists = false

		try queryStatement.fetch { row in
			_ = row.integer()
			let name = row.string()
			if name == columnName {
				columnExists = true
			}
		}

		try queryStatement.finalize()

		return columnExists
	}

	private func createEventsTableIfNeeded() throws {
		let createTableCommand = """
			CREATE TABLE IF NOT EXISTS \(Const.eventsTableName)(
			Id INTEGER PRIMARY KEY,
			SeqNum INTEGER,
			Name TEXT,
			SessionId TEXT,
			Dimensions TEXT,
			Value REAL,
			Unit TEXT,
			Currency TEXT,
			HappenedAt Value,
			SdkVersion TEXT);
			"""
		try createTableIfNeeded(createTableCommand: createTableCommand)
	}

	private func createMessagesTableIfNeeded() throws {
		let createTableCommand = """
			CREATE TABLE IF NOT EXISTS \(Const.messagesTableName)(
			Id INTEGER PRIMARY KEY,
			Level TEXT,
			Message TEXT,
			Fields TEXT,
			Timestamp TEXT,
			CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP);
			"""
		try createTableIfNeeded(createTableCommand: createTableCommand)
	}

	private func createMetricsTableIfNeeded() throws {
		let createTableCommand = """
			CREATE TABLE IF NOT EXISTS \(Const.metricsTableName)(
			Id INTEGER PRIMARY KEY,
			Metric TEXT,
			Dimensions TEXT,
			Value REAL,
			Unit TEXT,
			Timestamp TEXT,
			CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP);
			"""
		try createTableIfNeeded(createTableCommand: createTableCommand)
	}

	private func createTableIfNeeded(
		createTableCommand: String
	) throws {
		var createTableStatement = try Statement(db: db, command: createTableCommand, errorProvider: { DefaultSqliteDriverError.tableCreation($0) })

		try createTableStatement.execute()

		try createTableStatement.finalize()
	}

	private func deleteEvents(
		eventIds: [Int]
	) throws {
		try deleteRows(tableName: Const.eventsTableName, rowIds: eventIds)
	}

	private func deleteMessagesAndMetrics(
		messageIds: [Int],
		metricIds: [Int]
	) throws {
		try deleteRows(tableName: Const.messagesTableName, rowIds: messageIds)
		try deleteRows(tableName: Const.metricsTableName, rowIds: metricIds)
	}

	private func deleteRows(
		tableName: String,
		rowIds: [Int]
	) throws {
		guard !rowIds.isEmpty else { return }

		let idsWithCommas = rowIds.map(String.init).joined(separator: ", ")

		let deleteCommand = "DELETE FROM \(tableName) WHERE Id IN (\(idsWithCommas));"
		var deleteStatement = try Statement(db: db, command: deleteCommand, errorProvider: { DefaultSqliteDriverError.removal($0) })

		try deleteStatement.execute()

		try deleteStatement.finalize()
	}

	private func insertEvent(
		_ event: StorableEvent
	) throws {
		let insertCommand = """
			INSERT INTO \(Const.eventsTableName) (Id, SeqNum, Name, SessionId, Dimensions, Value, Unit, Currency, HappenedAt, SdkVersion) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
			"""
		var insertStatement = try Statement(db: db, command: insertCommand, errorProvider: { DefaultSqliteDriverError.insertion($0) })

		_ = try insertStatement.insert(
			columns: [
				event.id.columnData(),
				event.sequenceNumber.columnData(),
				event.event.name.columnData(),
				event.event.sessionId.columnData(),
				event.event.dimensions.columnData(),
				event.event.value.columnData(),
				event.event.unit?.rawValue.columnData(),
				event.event.currency?.columnData(),
				event.event.happenedAt?.columnData(),
				event.sdkVersion.columnData(),
			]
		)

		try insertStatement.finalize()
	}

	private func insertMessage(
		_ message: StoredLogMessage
	) throws {
		let insertCommand = """
			INSERT INTO \(Const.messagesTableName) (Id, Level, Message, Fields, Timestamp) VALUES (?, ?, ?, ?, ?);
			"""
		var insertStatement = try Statement(db: db, command: insertCommand, errorProvider: { DefaultSqliteDriverError.insertion($0) })

		_ = try insertStatement.insert(columns: [
			message.id.columnData(),
			message.message.level.columnData(),
			message.message.message.columnData(),
			message.message.fields.columnData(),
			message.message.timestamp.columnData(),
		])

		try insertStatement.finalize()
	}

	private func insertMetric(
		_ metric: StoredLogMetric
	) throws {
		let insertCommand = """
			INSERT INTO \(Const.metricsTableName) (Id, Metric, Dimensions, Value, Unit, Timestamp) VALUES (?, ?, ?, ?, ?, ?);
			"""
		var insertStatement = try Statement(db: db, command: insertCommand, errorProvider: { DefaultSqliteDriverError.insertion($0) })

		_ = try insertStatement.insert(columns: [
			metric.id.columnData(),
			metric.metric.metric.columnData(),
			metric.metric.dimensions.columnData(),
			metric.metric.value.columnData(),
			metric.metric.unit.columnData(),
			metric.metric.timestamp.columnData(),
		])

		try insertStatement.finalize()
	}

	private func openDatabase(url: URL) throws {
		let openingResult = sqlite3_open(url.path, &db)
		guard openingResult == SQLITE_OK else {
			let errMsg = String(cString: sqlite3_errmsg(db))
			throw DefaultSqliteDriverError.databaseOpening(errMsg)
		}
	}

	private func closeDatabase() throws {
		guard db != nil else { return }

		let result = sqlite3_close(db)
		if result != SQLITE_OK {
			let errMsg = String(cString: sqlite3_errmsg(db))
			throw DefaultSqliteDriverError.databaseOpening("Failed to close database: \(errMsg)")
		}
		db = nil
	}

	private func selectEvents() throws -> [StorableEvent] {
		var events = [StorableEvent]()

		let fetchCommand = "SELECT * FROM \(Const.eventsTableName);"
		var fetchStatement = try Statement(db: db, command: fetchCommand, errorProvider: { DefaultSqliteDriverError.fetching($0) })

		try fetchStatement.fetch { row in
			let id = row.integer()
			let sequenceNumber = row.integer()
			_ = row.string()
			let sessionId = row.string()
			let dimensions = row.json()
			let value = row.double()
			let unit = row.opt { row in Unit(rawValue: row.string()) } ?? nil  // swiftlint:disable:this redundant_nil_coalescing
			let currency = row.opt { row in row.string() }
			let happenedAt = row.opt { row in row.date() }
			let sdkVersionObject = row.json()

			guard let majorString = sdkVersionObject["major"], let major = UInt32(majorString),
				let minorString = sdkVersionObject["minor"], let minor = UInt32(minorString),
				let patchString = sdkVersionObject["patch"], let patch = UInt32(patchString),
				let name = sdkVersionObject["name"]
			else { return }

			events.append(
				StorableEvent(
					id: id,
					event: PublishableUserEvent(
						name: name,
						sessionId: sessionId,
						dimensions: dimensions,
						value: value,
						unit: unit,
						currency: currency,
						happenedAt: happenedAt
					),
					sequenceNumber: sequenceNumber,
					sdkVersion: VersionImpl(major: major, minor: minor, patch: patch, name: name)
				)
			)
		}

		try fetchStatement.finalize()

		return events
	}

	private func selectMessages(
		blockSize: Int
	) throws -> (messages: [StoredLogMessage], messagesToDelete: [StoredLogMessage]) {
		var messages = [StoredLogMessage]()
		var messagesToDelete = [StoredLogMessage]()

		let cutoff = Date(timeIntervalSinceNow: -Const.maxRetentionTime)

		let fetchCommand = "SELECT * FROM \(Const.messagesTableName) ORDER BY Id ASC LIMIT \(blockSize) OFFSET 0;"
		var fetchStatement = try Statement(db: db, command: fetchCommand, errorProvider: { DefaultSqliteDriverError.fetching($0) })

		try fetchStatement.fetch { row in
			let id = row.integer()
			let level = row.string()
			let message = row.string()
			let fields = row.json()
			let timestamp = row.string()
			let date = isoFormatter.date(from: timestamp)

			if let date, date > cutoff {
				messages.append(
					StoredLogMessage(
						id: Int(id),
						message: DTOLogMessage(level, message, fields, date)
					)
				)
			} else {
				messagesToDelete.append(
					StoredLogMessage(
						id: Int(id),
						message: DTOLogMessage(level, message, fields, date ?? cutoff)
					)
				)
			}
		}

		try fetchStatement.finalize()

		return (messages, messagesToDelete)
	}

	private func selectMetrics(
		blockSize: Int
	) throws -> (metrics: [StoredLogMetric], metricsToDelete: [StoredLogMetric]) {
		var metrics = [StoredLogMetric]()
		var metricsToDelete = [StoredLogMetric]()

		let cutoff = Date(timeIntervalSinceNow: -Const.maxRetentionTime)

		let fetchCommand = "SELECT * FROM \(Const.metricsTableName) ORDER BY Id ASC LIMIT \(blockSize) OFFSET 0;"
		var fetchStatement = try Statement(db: db, command: fetchCommand, errorProvider: { DefaultSqliteDriverError.fetching($0) })

		try fetchStatement.fetch { row in
			let id = row.integer()
			let metric = row.string()
			let dimensions = row.json()
			let value = row.double()
			let unit = row.string()
			let timestamp = row.string()
			let date = isoFormatter.date(from: timestamp)

			if let date, date > cutoff {
				metrics.append(
					StoredLogMetric(
						id: Int(id),
						metric: DTOLogMetric(metric, dimensions, value, unit, date)
					)
				)
			} else {
				metricsToDelete.append(
					StoredLogMetric(
						id: Int(id),
						metric: DTOLogMetric(metric, dimensions, value, unit, date ?? cutoff)
					)
				)
			}
		}

		try fetchStatement.finalize()

		return (metrics, metricsToDelete)
	}
}
