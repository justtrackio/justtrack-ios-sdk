@testable import JustTrackSDK

extension DTOAttributionRequestDevice {
	static func fixture(
		name: String = "iPhone",
		model: String = "iPhone 12",
		product: String = "iPhone 12,3",
		type: DeviceType = .phone,
		os: DTOAttributionRequestDeviceOS = DTOAttributionRequestDeviceOS(version: "14.4.2", name: "iOS"),
		display: DTOAttributionRequestDeviceDisplay = DTOAttributionRequestDeviceDisplay(width: 390, height: 844)
	) -> DTOAttributionRequestDevice {
		DTOAttributionRequestDevice(
			name: name,
			model: model,
			product: product,
			type: type,
			os: os,
			display: display
		)
	}
}
