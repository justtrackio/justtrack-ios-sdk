import Foundation
import SQLite3
import XCTest

@testable import JustTrackSDK

final class DefaultSqliteDriverTests: XCTestCase {
	private var createdFileURLs: [URL] = []

	override func tearDown() {
		let fileManager = FileManager.default
		for url in createdFileURLs {
			try? fileManager.removeItem(at: url)
		}
		createdFileURLs = []
		super.tearDown()
	}

	private func documentsDirectory() throws -> URL {
		try FileManager.default.url(
			for: .documentDirectory,
			in: .userDomainMask,
			appropriateFor: nil,
			create: true
		)
	}

	private func urls(for databaseName: String) throws -> (v1: URL, v2: URL) {
		let dir = try documentsDirectory()
		let v1 = dir.appendingPathComponent("\(databaseName).sqlite")
		let v2 = dir.appendingPathComponent("\(databaseName)_V2.sqlite")
		createdFileURLs.append(contentsOf: [v1, v2])
		return (v1, v2)
	}

	// MARK: - V1 → V2 migration copy (line 50)

	func testInitCopiesLegacyV1DatabaseToV2WhenV2DoesNotExist() throws {
		let databaseName = "JT_LegacyCopy_\(UUID().uuidString)"
		let paths = try urls(for: databaseName)

		// Create a non-empty file at the V1 path so that fileExists(V1) is true.
		try Data([0]).write(to: paths.v1)
		XCTAssertTrue(FileManager.default.fileExists(atPath: paths.v1.path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: paths.v2.path))

		// init should hit the copy branch and proceed despite the file being
		// invalid sqlite — sqlite3_open will succeed on any path and then
		// PRAGMA/CREATE TABLE will reset/overwrite the file contents.
		let driver = try DefaultSqliteDriver(databaseName: databaseName)
		XCTAssertNotNil(driver)
		XCTAssertTrue(FileManager.default.fileExists(atPath: paths.v2.path))

		try driver.closeDatabaseForTesting()
	}

	// MARK: - version > 1 release-mode reset (lines 58–68)

	func testInitResetsDatabaseWhenVersionIsHigherThanSupportedInReleaseMode() throws {
		let databaseName = "JT_HigherVersion_\(UUID().uuidString)"

		// First, create a working DB and bump its user_version to 2.
		do {
			let driver = try DefaultSqliteDriver(databaseName: databaseName)
			let dir = try documentsDirectory()
			let v2URL = dir.appendingPathComponent("\(databaseName)_V2.sqlite")
			createdFileURLs.append(v2URL)
			try driver.closeDatabaseForTesting()

			// Bump version manually with a separate sqlite handle.
			var db: OpaquePointer?
			XCTAssertEqual(sqlite3_open(v2URL.path, &db), SQLITE_OK)
			XCTAssertEqual(sqlite3_exec(db, "PRAGMA user_version = 2;", nil, nil, nil), SQLITE_OK)
			sqlite3_close(db)
		}

		// Re-open in release mode — should hit the reset branch and succeed.
		let driver = try DefaultSqliteDriver(databaseName: databaseName, isDebugBuild: false)
		XCTAssertNotNil(driver)
		try driver.closeDatabaseForTesting()
	}

	// MARK: - performMigrationToVersion1 ALTER TABLE branch (lines 184–211)

	func testInitMigratesLegacyEventsTableToAddSdkVersionColumn() throws {
		let databaseName = "JT_AlterTable_\(UUID().uuidString)"
		let dir = try documentsDirectory()
		let v2URL = dir.appendingPathComponent("\(databaseName)_V2.sqlite")
		createdFileURLs.append(v2URL)

		// Manually create a legacy V2 file with an Events table lacking the
		// SdkVersion column. This forces performMigrationToVersion1 to take
		// the ALTER TABLE path.
		var db: OpaquePointer?
		XCTAssertEqual(sqlite3_open(v2URL.path, &db), SQLITE_OK)
		let legacyCreate = """
			CREATE TABLE Events (
				Id INTEGER PRIMARY KEY,
				SeqNum INTEGER,
				Name TEXT,
				SessionId TEXT,
				Dimensions TEXT,
				Value REAL,
				Unit TEXT,
				Currency TEXT,
				HappenedAt Value
			);
			"""
		XCTAssertEqual(sqlite3_exec(db, legacyCreate, nil, nil, nil), SQLITE_OK)
		// Insert a row that should be deleted by the migration.
		XCTAssertEqual(
			sqlite3_exec(db, "INSERT INTO Events (Id, SeqNum, Name) VALUES (1, 1, 'legacy');", nil, nil, nil),
			SQLITE_OK
		)
		sqlite3_close(db)

		// Open via the driver — should ALTER and DELETE.
		let driver = try DefaultSqliteDriver(databaseName: databaseName)
		let events = try driver.fetchEvents()
		XCTAssertEqual(events.count, 0, "Migration should delete legacy rows")
		try driver.closeDatabaseForTesting()
	}

	// MARK: - openDatabase failure (lines 384–385)

	func testInitThrowsWhenDatabasePathCannotBeOpened() throws {
		// Use a database name that contains a path separator pointing to a
		// non-existent directory. sqlite3_open will fail when it cannot
		// create the file there.
		let databaseName = "JT_BadPath_\(UUID().uuidString)/nested/missing"
		XCTAssertThrowsError(try DefaultSqliteDriver(databaseName: databaseName)) { error in
			guard case DefaultSqliteDriverError.databaseOpening = error else {
				XCTFail("Expected databaseOpening error, got \(error)")
				return
			}
		}
	}

	// MARK: - performMigrationToVersion1 rollback path (lines 200–201)

	func testInitThrowsWhenMigrationAlterTableFailsDueToDuplicateColumn() throws {
		let databaseName = "JT_AlterFail_\(UUID().uuidString)"
		let dir = try documentsDirectory()
		let v2URL = dir.appendingPathComponent("\(databaseName)_V2.sqlite")
		createdFileURLs.append(v2URL)

		// Pre-create the Events table with a column whose name differs only
		// by case ("sdkversion"). SQLite identifiers are case-insensitive, so
		// `PRAGMA table_info` returns "sdkversion" (causing `columnExists`'s
		// exact "SdkVersion" comparison to fail) while `ALTER TABLE ... ADD
		// COLUMN SdkVersion` throws "duplicate column name", forcing the
		// migration to rollback and rethrow.
		var db: OpaquePointer?
		XCTAssertEqual(sqlite3_open(v2URL.path, &db), SQLITE_OK)
		let legacyCreate = """
			CREATE TABLE Events (
				Id INTEGER PRIMARY KEY,
				SeqNum INTEGER,
				Name TEXT,
				sdkversion TEXT
			);
			"""
		XCTAssertEqual(sqlite3_exec(db, legacyCreate, nil, nil, nil), SQLITE_OK)
		sqlite3_close(db)

		XCTAssertThrowsError(try DefaultSqliteDriver(databaseName: databaseName)) { error in
			guard case DefaultSqliteDriverError.tableCreation = error else {
				XCTFail("Expected tableCreation error, got \(error)")
				return
			}
		}
	}

	// MARK: - closeDatabase direct invocation (lines 389–398)

	func testCloseDatabaseIsIdempotentAndCanBeCalledExplicitly() throws {
		let driver = try DefaultSqliteDriver(databaseName: "JT_Close_\(UUID().uuidString)")
		try driver.closeDatabaseForTesting()
		// Second call hits the `guard db != nil else { return }` path.
		try driver.closeDatabaseForTesting()
	}

	// MARK: - selectMessages / selectMetrics older-than-cutoff branches
	//        (lines 474–479, 516–521)

	func testFetchNextBlockDeletesMessagesOlderThanRetentionWindow() throws {
		let driver = try DefaultSqliteDriver(databaseName: "JT_StaleMsg_\(UUID().uuidString)")

		// Insert one fresh message (kept) and one stale one (>3 days old).
		let freshTimestamp = Date()
		let staleTimestamp = Date(timeIntervalSinceNow: -(4 * 24 * 3600))

		try driver.storeMessage(
			StoredLogMessage(id: 1, message: DTOLogMessage("info", "fresh", [:], freshTimestamp))
		)
		try driver.storeMessage(
			StoredLogMessage(id: 2, message: DTOLogMessage("info", "stale", [:], staleTimestamp))
		)

		var readMessages: [StoredLogMessage] = []
		try driver.fetchNextBlockOfMessagesAndMetrics(
			blockSize: 100,
			onReadLogMessage: { readMessages.append($0) },
			onReadLogMetric: { _ in }
		)

		XCTAssertEqual(readMessages.count, 1)
		XCTAssertEqual(readMessages.first?.message.message, "fresh")

		// The stale row should have been deleted; second fetch returns the
		// fresh one only (after we delete it via removeMessagesAndMetrics).
		try driver.removeMessagesAndMetrics(messageIds: [1], metricIds: [])

		var secondPass: [StoredLogMessage] = []
		try driver.fetchNextBlockOfMessagesAndMetrics(
			blockSize: 100,
			onReadLogMessage: { secondPass.append($0) },
			onReadLogMetric: { _ in }
		)
		XCTAssertTrue(secondPass.isEmpty)

		try driver.closeDatabaseForTesting()
	}

	func testFetchNextBlockDeletesMetricsOlderThanRetentionWindow() throws {
		let driver = try DefaultSqliteDriver(databaseName: "JT_StaleMetric_\(UUID().uuidString)")

		let freshTimestamp = Date()
		let staleTimestamp = Date(timeIntervalSinceNow: -(4 * 24 * 3600))

		try driver.storeMetric(
			StoredLogMetric(id: 1, metric: DTOLogMetric("fresh.metric", [:], 1.0, "ms", freshTimestamp))
		)
		try driver.storeMetric(
			StoredLogMetric(id: 2, metric: DTOLogMetric("stale.metric", [:], 2.0, "ms", staleTimestamp))
		)

		var readMetrics: [StoredLogMetric] = []
		try driver.fetchNextBlockOfMessagesAndMetrics(
			blockSize: 100,
			onReadLogMessage: { _ in },
			onReadLogMetric: { readMetrics.append($0) }
		)

		XCTAssertEqual(readMetrics.count, 1)
		XCTAssertEqual(readMetrics.first?.metric.metric, "fresh.metric")

		try driver.closeDatabaseForTesting()
	}

	// MARK: - DefaultSqliteDriverError.errorDescription

	func testDefaultSqliteDriverErrorDescriptions() {
		XCTAssertEqual(
			DefaultSqliteDriverError.databaseOpening("oops").errorDescription,
			"<DefaultSqliteDriver> Database opening error: oops"
		)
		XCTAssertEqual(
			DefaultSqliteDriverError.tableCreation("oops").errorDescription,
			"<DefaultSqliteDriver> Table creation error: oops"
		)
		XCTAssertEqual(
			DefaultSqliteDriverError.insertion("oops").errorDescription,
			"<DefaultSqliteDriver> Insertion error: oops"
		)
		XCTAssertEqual(
			DefaultSqliteDriverError.removal("oops").errorDescription,
			"<DefaultSqliteDriver> Removal error: oops"
		)
		XCTAssertEqual(
			DefaultSqliteDriverError.fetching("oops").errorDescription,
			"<DefaultSqliteDriver> Fetching error: oops"
		)
	}
}
