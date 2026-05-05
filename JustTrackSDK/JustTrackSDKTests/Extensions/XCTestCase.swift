import XCTest

extension XCTestCase {
	static func clearDocumentsDirectory() throws {
		let fileManager = FileManager.default

		guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
			throw NSError(domain: "DirectoryError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not locate documents directory"])
		}

		let filesInDirectory = try fileManager.contentsOfDirectory(
			at: documentsPath,
			includingPropertiesForKeys: nil
		)

		for fileURL in filesInDirectory {
			try fileManager.removeItem(at: fileURL)
		}
	}
}
