import Foundation

struct InvalidFieldError: Error {
	fileprivate let message: String

	init(name: String, value: String, maxLength: Int, encoding: String) {
		self.message = "Invalid \(name) value: '\(value)'. It needs to be shorter than \(maxLength) characters and only include \(encoding) characters."
	}

	init(name: String, value: String, minLength: Int, maxLength: Int, encoding: String) {
		self.message = "Invalid \(name) value: '\(value)'. It needs to be between \(minLength) and \(maxLength) characters and only include \(encoding) characters."
	}

	init(name: String, value: Double) {
		self.message = "Invalid \(name) value: \(value). The field value needs to be finite."
	}

	init(name: String, value: String, encoding: String) {
		self.message = "Invalid \(name) value: \(value). \(encoding)"
	}

	init(fieldValue: [String: String], maxDimensions: Int, currentDimensions: Int) {
		self.message = "Too many dimensions: '\(fieldValue)'. The number of dimensions must not exceed \(maxDimensions). Current amount: \(currentDimensions)"
	}
}

extension InvalidFieldError: CustomStringConvertible {
	var description: String { message }
}

private func isAscii(_ c: Character) -> Bool {
	guard let c = c.asciiValue else {
		return false
	}

	return c >= 0x20 && c <= 0x7E
}

private func isIso88591(_ c: Character) -> Bool {
	return !c.unicodeScalars.contains(where: { c in
		let c = c.value

		return c < 0x20 || c > 0xFF || (c > 0x7E && c < 0xA0)
	})
}

func isValid(trackingId: String) -> Bool {
	return trackingId.count < 4096 && trackingId.allSatisfy(isAscii)
}

func isValid(trackingProvider: String) -> Bool {
	return trackingProvider.count < 4096 && trackingProvider.allSatisfy(isAscii)
}

func isValid(eventName: String) -> Bool {
	return eventName.count < 256 && eventName.allSatisfy(isIso88591)
}

func isValid(dimension: String) -> Bool {
	return dimension.count > 0 && dimension.count < 256 && dimension.range(of: "^[a-z0-9_]+$", options: .regularExpression) != nil
}

func isValid(dimension: String, value: String) -> Bool {
	if dimension == Dimension.jtToken.rawValue {
		// the token dimension is always valid - we can't restrict what apple stores in the receipt file
		return true
	}

	return value.count < 4096 && value.allSatisfy(isIso88591)
}

func isValid(customUserId: String) -> Bool {
	return !customUserId.isEmpty && customUserId.count < 4096 && customUserId.allSatisfy(isAscii)
}

func isValid(firebaseAppInstanceId: String) -> Bool {
	return firebaseAppInstanceId.count >= 8 && firebaseAppInstanceId.count < 256 && firebaseAppInstanceId.allSatisfy(isAscii)
}
