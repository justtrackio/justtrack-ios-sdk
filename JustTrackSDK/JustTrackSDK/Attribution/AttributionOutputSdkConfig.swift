import Foundation

struct AttributionOutputSdkConfig: Codable, Equatable {
	let log: Log
	let metric: Metric
	let event: Event
}

extension AttributionOutputSdkConfig {
	struct Log: Codable, Equatable {
		let rules: [Rule]
	}
}

extension AttributionOutputSdkConfig {
	struct Metric: Codable, Equatable {
		let rules: [Rule]
	}
}

extension AttributionOutputSdkConfig {
	struct Event: Codable, Equatable {
		let rules: [Rule]
	}
}

extension AttributionOutputSdkConfig {
	struct Rule: Codable, Equatable {
		enum CodingKeys: String, CodingKey {
			case name = "rule"
			case drop
			case dimensions
		}

		let name: String
		let drop: Bool
		let dimensions: [String: String]
	}
}

struct AttributionOutputSdkConfigContainer: Decodable {
	let sdkConfig: AttributionOutputSdkConfig?
}
