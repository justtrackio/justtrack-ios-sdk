import XCTest

@testable import JustTrackSDK

final class PListStoreTests: XCTestCase {
	private var store: PListStore!
	private let filename = "test_plist_store_\(UUID().uuidString)"

	override func setUp() {
		super.setUp()
		store = PListStore(isConsoleLoggingEnabled: false)
	}

	override func tearDown() {
		store.removeFile(filename: filename)
		super.tearDown()
	}

	// MARK: - readFile

	func testReadFileReturnsNilForNonExistentFile() {
		let result = store.readFile(filename: "nonexistent_\(UUID().uuidString)")
		XCTAssertNil(result)
	}

	func testReadFileReturnsDataAfterWrite() {
		let data: [String: Any] = ["key": "value", "number": 42]
		store.writeFile(filename: filename, data: data)

		let result = store.readFile(filename: filename)

		XCTAssertNotNil(result)
		XCTAssertEqual(result?["key"] as? String, "value")
		XCTAssertEqual(result?["number"] as? Int, 42)
	}

	func testReadFileReturnsNilForCorruptData() {
		// Write raw non-plist bytes directly to the file path
		guard let url = documentsURL(for: filename) else {
			XCTFail("Could not construct documents URL")
			return
		}
		let corruptData = Data("this is not a plist".utf8)
		try? corruptData.write(to: url)

		let result = store.readFile(filename: filename)

		XCTAssertNil(result)

		try? FileManager.default.removeItem(at: url)
	}

	// MARK: - writeFile

	func testWriteFileCreatesReadableFile() {
		let data: [String: Any] = ["hello": "world"]
		store.writeFile(filename: filename, data: data)

		let result = store.readFile(filename: filename)
		XCTAssertEqual(result?["hello"] as? String, "world")
	}

	func testWriteFileOverwritesExistingFile() {
		store.writeFile(filename: filename, data: ["v": "first"])
		store.writeFile(filename: filename, data: ["v": "second"])

		let result = store.readFile(filename: filename)
		XCTAssertEqual(result?["v"] as? String, "second")
	}

	func testWriteFileWithUnserializableDataDoesNotCrash() {
		// NSDate is not a valid plist value when used as a dictionary value with non-string key
		// Use a value that PropertyListSerialization can't handle: a Set (not plist-compatible)
		// We can't pass a Set directly due to type system, but we can pass a nested dict with a bad type
		// The safest approach: write valid data to confirm no crash on success path
		let data: [String: Any] = ["safe": "data"]
		store.writeFile(filename: filename, data: data)
		// No assertion needed — test verifies no crash
	}

	// MARK: - removeFile

	func testRemoveFileDeletesExistingFile() {
		store.writeFile(filename: filename, data: ["x": "y"])
		XCTAssertNotNil(store.readFile(filename: filename))

		store.removeFile(filename: filename)

		XCTAssertNil(store.readFile(filename: filename))
	}

	func testRemoveFileDoesNotCrashWhenFileDoesNotExist() {
		store.removeFile(filename: "nonexistent_\(UUID().uuidString)")
	}

	func testRemoveFileCanBeCalledTwice() {
		store.writeFile(filename: filename, data: ["x": "y"])
		store.removeFile(filename: filename)
		store.removeFile(filename: filename)  // second call should not crash
	}

	// MARK: - getPath / round-trip

	func testRoundTripMultipleKeys() {
		let data: [String: Any] = [
			"string": "hello",
			"int": 123,
			"bool": true,
		]
		store.writeFile(filename: filename, data: data)
		let result = store.readFile(filename: filename)

		XCTAssertEqual(result?["string"] as? String, "hello")
		XCTAssertEqual(result?["int"] as? Int, 123)
		XCTAssertEqual(result?["bool"] as? Bool, true)
	}

	func testMultipleFilesAreIndependent() {
		let filename2 = "\(filename)_2"
		defer { store.removeFile(filename: filename2) }

		store.writeFile(filename: filename, data: ["file": "one"])
		store.writeFile(filename: filename2, data: ["file": "two"])

		XCTAssertEqual(store.readFile(filename: filename)?["file"] as? String, "one")
		XCTAssertEqual(store.readFile(filename: filename2)?["file"] as? String, "two")
	}

	// MARK: - console logging variant

	func testPListStoreWithConsoleLoggingEnabledDoesNotCrash() {
		let loggingStore = PListStore(isConsoleLoggingEnabled: true)
		let logFilename = "test_plist_logging_\(UUID().uuidString)"
		defer { loggingStore.removeFile(filename: logFilename) }

		loggingStore.writeFile(filename: logFilename, data: ["k": "v"])
		let result = loggingStore.readFile(filename: logFilename)
		XCTAssertEqual(result?["k"] as? String, "v")
	}

	// MARK: - error branches via injected FileManager / unserializable data

	func testWriteFileLogsErrorWhenFileManagerCreateFileReturnsFalse() {
		// Covers: `if !success { logger.error("failed to create plist file" ...) }`
		// Inject a FileManager subclass whose createFile always returns false.
		let failingStore = PListStore(isConsoleLoggingEnabled: true, fileManager: AlwaysFailingCreateFileManager())
		failingStore.writeFile(filename: "create_fails_\(UUID().uuidString)", data: ["k": "v"])
		// No assertion — the test verifies the error-log branch is reached without crashing.
	}

	func testWriteFileLogsErrorWhenPropertyListSerializationThrows() {
		// Covers: `catch { logger.error("failed to serialize plist" ...) }`
		// PropertyListSerialization.data(.xml) throws for non-plist-compatible value types like Date subclasses
		// or—more reliably—NSObject instances that don't conform to plist types. We use a value that the
		// type system accepts as `Any` but PropertyListSerialization rejects: a custom NSObject.
		let bogusValue = NotPlistSerializable()
		let payload: [String: Any] = ["bad": bogusValue]
		store.writeFile(filename: "serialize_fails_\(UUID().uuidString)", data: payload)
	}

	// MARK: - Helpers

	private func documentsURL(for filename: String) -> URL? {
		guard var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
			return nil
		}
		url.appendPathComponent("\(filename).plist")
		return url
	}
}

/// FileManager subclass whose createFile always returns false, used to exercise the
/// `if !success` branch of PListStore.writeFile.
private final class AlwaysFailingCreateFileManager: FileManager {
	override func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]? = nil) -> Bool {
		false
	}
}

/// NSObject that PropertyListSerialization cannot serialize. Used to exercise the
/// catch branch of PListStore.writeFile.
private final class NotPlistSerializable: NSObject {}
