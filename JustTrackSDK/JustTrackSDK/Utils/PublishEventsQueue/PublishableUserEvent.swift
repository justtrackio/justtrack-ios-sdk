import Foundation

struct PublishableUserEvent: Equatable, CustomStringConvertible {
	let name: String
	let sessionId: String
	let dimensions: [String: String]
	let value: Double
	let unit: Unit?
	let currency: String?
	let happenedAt: Date?

	init(
		name: String,
		sessionId: String,
		dimensions: [String: String],
		value: Double,
		unit: Unit?,
		currency: String?,
		happenedAt: Date?
	) {
		self.name = name
		self.sessionId = sessionId
		self.dimensions = dimensions
		if unit == .some(.seconds) {
			self.value = value * 1000
			self.unit = .milliseconds
		} else {
			self.value = value
			self.unit = unit
		}
		self.currency = currency
		self.happenedAt = happenedAt
	}

	init?(
		encoded: [String: Any]
	) {
		guard let name = encoded["name"] as? String else { return nil }
		self.name = name
		guard let sessionId = encoded["sessionId"] as? String else { return nil }
		self.sessionId = sessionId
		guard let dimensionsObject = encoded["dimensions"] as? [String: Any] else { return nil }
		var parsedDimensions: [String: String] = [:]
		for dimension in dimensionsObject {
			if let value = dimension.value as? String {
				parsedDimensions[dimension.key] = value
			}
		}
		self.dimensions = parsedDimensions
		guard let value = encoded["value"] as? Double else { return nil }
		self.value = value
		if let unit = encoded["unit"] as? String {
			guard let unit = Unit(rawValue: unit) else { return nil }
			self.unit = unit
		} else {
			self.unit = nil
		}
		self.currency = encoded["currency"] as? String
		self.happenedAt = nil
	}

	public var description: String {
		var dimensionsString = ""
		if !dimensions.isEmpty {
			dimensionsString = ", dimensions = ["
			var firstDimension = true
			for (k, v) in dimensions {
				if firstDimension {
					firstDimension = false
				} else {
					dimensionsString += ", "
				}
				dimensionsString += "\(k) = \(v)"
			}
			dimensionsString += "]"
		}

		let unitString: String
		if let unit {
			unitString = unit.rawValue
		} else if let currency {
			unitString = currency
		} else {
			unitString = "null"
		}

		return "[PublishableUserEvent \(name)\(dimensionsString), value = \(value) \(unitString), sessionId = \(sessionId), happenedAt = \(happenedAt?.description ?? "now")]"
	}

	func encode() -> [String: Any] {
		var encodedDimensions: [String: Any] = [:]
		for dimension in dimensions {
			encodedDimensions[dimension.key] = dimension.value
		}
		var result: [String: Any] = [
			"name": name,
			"sessionId": sessionId,
			"dimensions": encodedDimensions,
			"value": value,
		]
		if let unit {
			result["unit"] = unit.rawValue
		}
		if let currency {
			result["currency"] = currency
		}

		return result
	}
}

extension PublishableUserEvent {
	static func build(
		batch: PublishingBatch,
		idfa: String?,
		userId: StringID,
		installId: StringID,
		idfvProvider: AdTrackingProvider,
		applicationVersion: AppVersion,
		platformType: PlatformType
	) -> DTOUserEvent {
		let deviceInfo = DeviceInfo(idfvProvider: idfvProvider)
		let user = DTOUserEventUser(
			installInstanceId: installId.value,
			countryIso: getCurrentCountry(),
			localeCode: getCurrentLocale(),
			deviceId: idfa,
			idfv: deviceInfo.idfv?.value,
			userId: userId.value
		)
		let device = DTOUserEventDevice(
			connectionType: getNetworkType().stringValue,
			os: DTOUserEventDeviceOS(
				name: DeviceInfo.getSystemName(),
				version: deviceInfo.osVersion
			),
			date: Date()
		)
		var events: [DTOUserEventEvent] = []
		events.reserveCapacity(batch.events.count)
		for event in batch.events {
			let baseEvent = event.baseEvent()
			events.append(
				DTOUserEventEvent(
					id: event.eventId().value,
					name: baseEvent.name,
					dimensions: baseEvent.dimensions,
					value: baseEvent.value,
					unit: baseEvent.unit,
					currency: baseEvent.currency,
					sessionId: baseEvent.sessionId,
					happenedAt: event.happenedAt(),
					sequenceNumber: event.sequenceNumber()
				)
			)
		}
		let appVersion = DTOAppVersion(applicationVersion)
		let sdkVersion = DTOSdkVersion(batch.sdkVersion, platformType: platformType)
		let dto = DTOUserEvent(
			appVersion: appVersion,
			sdkVersion: sdkVersion,
			user: user,
			device: device,
			events: events
		)
		return dto
	}
}
