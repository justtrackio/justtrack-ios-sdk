import CoreTelephony
import Foundation
import MachO
import UIKit

func getCurrentCountry() -> String? {
	return mapRegionCode(NSLocale.current.regionCode)
}

internal func mapRegionCode(_ iso: String?) -> String? {
	switch iso {
	case "AC":
		return "GB"
	case "CP":
		return "FR"
	case "CQ":
		return "GB"
	case "DG":
		return "GB"
	case "EA":
		return "ES"
	case "EU":
		return nil  // european union
	case "EZ":
		return nil  // euro zone
	case "FX":
		return "FR"
	case "IC":
		return "ES"
	case "SU":
		return "RU"  // soviet union
	case "TA":
		return "GB"
	case "UK":
		return "GB"  // united kingdom
	case "UN":
		return nil  // united nations
	default:
		return iso
	}
}

func getCurrentLocale() -> String {
	return NSLocale.current.identifier
}

enum ConnectionType {
	case offline
	case cellularUnknown
	case cellular2g
	case cellular3g
	case cellular4g
	case cellular5g
	case wifi
	case unknown

	var stringValue: String {
		switch self {
		case .offline:
			return "offline"
		case .cellularUnknown:
			return "cellular_unknown"
		case .cellular2g:
			return "cellular_2g"
		case .cellular3g:
			return "cellular_3g"
		case .cellular4g:
			return "cellular_4g"
		case .cellular5g:
			return "cellular_5g"
		case .wifi:
			return "wifi"
		case .unknown:
			return "unknown"
		}
	}

	private var preferenceValue: Int {
		switch self {
		case .offline:
			return 0
		case .cellularUnknown:
			return 10
		case .cellular2g:
			return 11
		case .cellular3g:
			return 12
		case .cellular4g:
			return 13
		case .cellular5g:
			return 14
		case .wifi:
			return 100
		case .unknown:
			return 1
		}
	}

	func betterThan(_ other: ConnectionType) -> Bool {
		return self.preferenceValue > other.preferenceValue
	}
}

func getTechnologyMap() -> [String: ConnectionType] {
	var result: [String: ConnectionType] = [
		CTRadioAccessTechnologyGPRS: .cellular2g,
		CTRadioAccessTechnologyEdge: .cellular2g,
		CTRadioAccessTechnologyCDMA1x: .cellular2g,
		CTRadioAccessTechnologyWCDMA: .cellular3g,
		CTRadioAccessTechnologyHSDPA: .cellular3g,
		CTRadioAccessTechnologyHSUPA: .cellular3g,
		CTRadioAccessTechnologyCDMAEVDORev0: .cellular3g,
		CTRadioAccessTechnologyCDMAEVDORevA: .cellular3g,
		CTRadioAccessTechnologyCDMAEVDORevB: .cellular3g,
		CTRadioAccessTechnologyeHRPD: .cellular3g,
		CTRadioAccessTechnologyLTE: .cellular4g,
	]

	if #available(iOS 14.1, *) {
		result[CTRadioAccessTechnologyNRNSA] = .cellular5g
		result[CTRadioAccessTechnologyNR] = .cellular5g
	}

	return result
}

let technologyMap: [String: ConnectionType] = getTechnologyMap()

func getNetworkType() -> ConnectionType {
	do {
		let reachability: Reachability = try Reachability()
		try reachability.startNotifier()
		defer { reachability.stopNotifier() }
		let status = reachability.connection
		if status == .unavailable {
			return .offline
		}
		if status == .wifi {
			return .wifi
		}
		if status == .cellular {
			let networkInfo = CTTelephonyNetworkInfo()
			if #available(iOS 12.0, *) {
				var result = ConnectionType.cellularUnknown

				for (_, carrierType) in networkInfo.serviceCurrentRadioAccessTechnology ?? [:] {
					if let technology = technologyMap[carrierType] {
						if technology.betterThan(result) {
							result = technology
						}
					}
				}

				return result
			} else {
				if let carrierType = networkInfo.currentRadioAccessTechnology {
					return technologyMap[carrierType] ?? .cellularUnknown
				}
			}
			return .cellularUnknown
		}
		return .unknown
	} catch {
		return .unknown
	}
}

enum DeviceType {
	case phone
	case tablet

	var stringValue: String {
		switch self {
		case .phone:
			return "phone"
		case .tablet:
			return "tablet"
		}
	}
}

struct DeviceInfo {
	let idfv: StringID?
	let name: String
	let model: String
	let product: String
	let type: DeviceType
	let osVersion: String
	let osName: String
	let displayWidth: Int
	let displayHeight: Int

	internal init(
		idfv: StringID? = nil,
		name: String = "",
		model: String = "",
		product: String = "",
		type: DeviceType = .phone,
		osVersion: String = "",
		osName: String = "",
		displayWidth: Int = 0,
		displayHeight: Int = 0
	) {
		self.idfv = idfv
		self.name = name
		self.model = model
		self.product = product
		self.type = type
		self.osVersion = osVersion
		self.osName = osName
		self.displayWidth = displayWidth
		self.displayHeight = displayHeight
	}

	init(idfvProvider: AdTrackingProvider) {
		let device = UIDevice.current
		self.idfv = idfvProvider.provideIDFV()
		self.name = device.name
		self.model = DeviceInfo.getModel()
		// not really something we have here, so we are just using the less expressive model from the device here
		self.product = DeviceInfo.getProduct()

		if device.userInterfaceIdiom == .pad {
			self.type = .tablet
		} else {
			self.type = .phone
		}

		self.osVersion = DeviceInfo.getSystemVersion()
		self.osName = DeviceInfo.getSystemName()

		let screen = UIScreen.main.bounds
		self.displayWidth = Int(screen.width)
		self.displayHeight = Int(screen.height)
	}

	internal static func getDevice() -> String {
		return getByName("hw.machine")
	}

	internal static func getProduct() -> String {
		return UIDevice.current.model
	}

	internal static func getSystemName() -> String {
		return UIDevice.current.systemName
	}

	internal static func getSystemVersion() -> String {
		return UIDevice.current.systemVersion
	}

	internal static func getBuild() -> String {
		return getByName("kern.osversion")
	}

	internal static func getMachine() -> String {
		let info = NXGetLocalArchInfo()

		if let info {
			return String(cString: info.pointee.description)
		}

		return getModel()
	}

	internal static func getModel() -> String {
		var systemInfo = utsname()
		uname(&systemInfo)

		return DeviceInfo.readString(systemInfo.machine)
	}

	internal static func getDarwinVersion() -> String {
		var systemInfo = utsname()
		uname(&systemInfo)

		return DeviceInfo.readString(systemInfo.release)
	}

	private static func readString(_ field: Any) -> String {
		let machineMirror = Mirror(reflecting: field)
		var base = String()
		base.reserveCapacity(Int(_SYS_NAMELEN))

		return machineMirror.children.reduce(into: base) { identifier, element in
			guard let value = element.value as? CChar, value != 0 else {
				return
			}

			identifier.append(Character(UnicodeScalar(UInt8(value))))
		}
	}

	private static func getByName(_ name: String) -> String {
		var bufferSize = 64
		guard let buffer = NSMutableData(length: bufferSize) else {
			return ""
		}

		let status = sysctlbyname(name, buffer.mutableBytes, &bufferSize, nil, 0)
		if status != 0 {
			return ""
		}

		// bufferSize contains the length of the returned C-String
		return String(decoding: buffer.prefix(upTo: bufferSize - 1), as: UTF8.self)  // swiftlint:disable:this optional_data_string_conversion
	}
}
