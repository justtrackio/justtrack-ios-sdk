import Foundation

class PListStore {
	private let logger: Logger
	private let fileManager: FileManager

	init(
		isConsoleLoggingEnabled: Bool
	) {
		logger = isConsoleLoggingEnabled ? LoggerImpl() : IdleLogger()
		fileManager = FileManager()
	}

	func readFile(filename: String) -> [String: Any]? {  // swiftlint:disable:this discouraged_optional_collection
		guard let path = getPath(filename: filename) else { return nil }
		guard let plistData = fileManager.contents(atPath: path) else { return nil }
		do {
			let result = try PropertyListSerialization.propertyList(from: plistData, format: nil)

			return result as? [String: Any]
		} catch {
			logger.error("failed to read file", LoggerFieldsImpl().with("filename", filename).with("exception", error))

			return nil
		}
	}

	func writeFile(filename: String, data: [String: Any]) {
		guard let path = getPath(filename: filename) else { return }
		do {
			let plistData = try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0)
			let success = fileManager.createFile(atPath: path, contents: plistData)
			if !success {
				logger.error("failed to create plist file", LoggerFieldsImpl().with("filename", filename).with("path", path))
			}
		} catch {
			logger.error("failed to serialize plist", LoggerFieldsImpl().with("filename", filename).with("exception", error))
		}
	}

	func removeFile(filename: String) {
		guard let path = getPath(filename: filename) else { return }
		do {
			try fileManager.removeItem(atPath: path)
		} catch {
			logger.error("failed to delete file", LoggerFieldsImpl().with("filename", filename).with("exception", error))
		}
	}

	private func getPath(filename: String) -> String? {
		guard var url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
		url.appendPathComponent("\(filename).plist")

		return url.absoluteString.replacingOccurrences(of: "file://", with: "")
	}
}
