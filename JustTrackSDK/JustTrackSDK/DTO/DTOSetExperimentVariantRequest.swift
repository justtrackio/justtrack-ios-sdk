import Foundation

struct DTOSetExperimentVariantRequest: Codable, Equatable {
	let installInstanceId: String
	let justtrackSdkVersion: String
	let appVersionName: String
	let appVersionCode: String
	let osVersion: String
	let experiment: String
	let variant: String
	let tags: [String]
	let happenedAt: String?

	func json() throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		return try encoder.encode(self)
	}
}

extension DTOSetExperimentVariantRequest {
	init(
		installId: StringID,
		sdkVersion: any Version,
		appVersion: AppVersion,
		osVersion: String,
		experiment: String,
		variant: String,
		tags: [String],
		happenedAt: Date?
	) {
		self.installInstanceId = installId.value
		self.justtrackSdkVersion = sdkVersion.name
		self.appVersionName = appVersion.name
		self.appVersionCode = appVersion.code
		self.osVersion = osVersion
		self.experiment = experiment
		self.variant = variant
		self.tags = tags

		if let happenedAt {
			let formatter = ISO8601DateFormatter()
			formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
			self.happenedAt = formatter.string(from: happenedAt)
		} else {
			self.happenedAt = nil
		}
	}
}
