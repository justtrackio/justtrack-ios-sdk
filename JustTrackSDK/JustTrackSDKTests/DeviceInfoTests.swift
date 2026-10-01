import CoreTelephony
import UIKit
import XCTest

@testable import JustTrackSDK

class DeviceInfoTests: XCTestCase {
	func testGetDevice() {
		let value = DeviceInfo.getDevice()

		// should be something like x86_64
		XCTAssertNotEqual("", value)
	}

	func testGetBuild() {
		let value = DeviceInfo.getBuild()

		// should be something like 21G115
		XCTAssertNotEqual("", value)
	}

	func testGetMachine() {
		let value = DeviceInfo.getMachine()

		// should be something like x86_64
		XCTAssertNotEqual("", value)
	}

	func testGetProduct() {
		let value = DeviceInfo.getProduct()

		// should be something like iPad
		XCTAssertNotEqual("", value)
	}

	func testGetSystemName() {
		let value = DeviceInfo.getSystemName()

		// should be something like iPadOS
		XCTAssertNotEqual("", value)
	}

	func testGetSystemVersion() {
		let value = DeviceInfo.getSystemVersion()

		// should be something like 15.5
		XCTAssertNotEqual("", value)
	}

	func testGetDarwinVersion() {
		let value = DeviceInfo.getDarwinVersion()

		// should be something like 21.6.0
		XCTAssertNotEqual("", value)
	}

	func testGetModelReturnsNonEmpty() {
		// getMachine() falls back to getModel() if NXGetLocalArchInfo returns nil
		let value = DeviceInfo.getModel()
		XCTAssertNotEqual("", value)
	}

	// MARK: - mapRegionCode

	func testMapRegionCodeAC() { XCTAssertEqual(mapRegionCode("AC"), "GB") }
	func testMapRegionCodeCP() { XCTAssertEqual(mapRegionCode("CP"), "FR") }
	func testMapRegionCodeCQ() { XCTAssertEqual(mapRegionCode("CQ"), "GB") }
	func testMapRegionCodeDG() { XCTAssertEqual(mapRegionCode("DG"), "GB") }
	func testMapRegionCodeEA() { XCTAssertEqual(mapRegionCode("EA"), "ES") }
	func testMapRegionCodeEU() { XCTAssertNil(mapRegionCode("EU")) }
	func testMapRegionCodeEZ() { XCTAssertNil(mapRegionCode("EZ")) }
	func testMapRegionCodeFX() { XCTAssertEqual(mapRegionCode("FX"), "FR") }
	func testMapRegionCodeIC() { XCTAssertEqual(mapRegionCode("IC"), "ES") }
	func testMapRegionCodeSU() { XCTAssertEqual(mapRegionCode("SU"), "RU") }
	func testMapRegionCodeTA() { XCTAssertEqual(mapRegionCode("TA"), "GB") }
	func testMapRegionCodeUK() { XCTAssertEqual(mapRegionCode("UK"), "GB") }
	func testMapRegionCodeUN() { XCTAssertNil(mapRegionCode("UN")) }
	func testMapRegionCodeDefaultPassesThrough() { XCTAssertEqual(mapRegionCode("DE"), "DE") }
	func testMapRegionCodeDefaultUS() { XCTAssertEqual(mapRegionCode("US"), "US") }
	func testMapRegionCodeNil() { XCTAssertNil(mapRegionCode(nil)) }

	func testGetCurrentCountryReturnsSomething() {
		// On a simulator, regionCode is set; can't predict the exact value but it goes through the switch.
		_ = getCurrentCountry()
	}

	// MARK: - getCurrentLocale

	func testGetCurrentLocaleMatchesNSLocale() {
		XCTAssertEqual(getCurrentLocale(), NSLocale.current.identifier)
	}

	// MARK: - ConnectionType.stringValue

	func testConnectionTypeStringValueOffline() {
		XCTAssertEqual(ConnectionType.offline.stringValue, "offline")
	}

	func testConnectionTypeStringValueCellularUnknown() {
		XCTAssertEqual(ConnectionType.cellularUnknown.stringValue, "cellular_unknown")
	}

	func testConnectionTypeStringValueCellular2g() {
		XCTAssertEqual(ConnectionType.cellular2g.stringValue, "cellular_2g")
	}

	func testConnectionTypeStringValueCellular3g() {
		XCTAssertEqual(ConnectionType.cellular3g.stringValue, "cellular_3g")
	}

	func testConnectionTypeStringValueCellular4g() {
		XCTAssertEqual(ConnectionType.cellular4g.stringValue, "cellular_4g")
	}

	func testConnectionTypeStringValueCellular5g() {
		XCTAssertEqual(ConnectionType.cellular5g.stringValue, "cellular_5g")
	}

	func testConnectionTypeStringValueWifi() {
		XCTAssertEqual(ConnectionType.wifi.stringValue, "wifi")
	}

	func testConnectionTypeStringValueUnknown() {
		XCTAssertEqual(ConnectionType.unknown.stringValue, "unknown")
	}

	// MARK: - ConnectionType.betterThan (covers all preferenceValue cases)

	func testConnectionTypeBetterThanWifiIsBest() {
		XCTAssertTrue(ConnectionType.wifi.betterThan(.cellular5g))
		XCTAssertTrue(ConnectionType.wifi.betterThan(.cellular4g))
		XCTAssertTrue(ConnectionType.wifi.betterThan(.cellular3g))
		XCTAssertTrue(ConnectionType.wifi.betterThan(.cellular2g))
		XCTAssertTrue(ConnectionType.wifi.betterThan(.cellularUnknown))
		XCTAssertTrue(ConnectionType.wifi.betterThan(.unknown))
		XCTAssertTrue(ConnectionType.wifi.betterThan(.offline))
	}

	func testConnectionTypeBetterThanCellular5gOver4g() {
		XCTAssertTrue(ConnectionType.cellular5g.betterThan(.cellular4g))
	}

	func testConnectionTypeBetterThanCellular4gOver3g() {
		XCTAssertTrue(ConnectionType.cellular4g.betterThan(.cellular3g))
	}

	func testConnectionTypeBetterThanCellular3gOver2g() {
		XCTAssertTrue(ConnectionType.cellular3g.betterThan(.cellular2g))
	}

	func testConnectionTypeBetterThanCellular2gOverUnknown() {
		XCTAssertTrue(ConnectionType.cellular2g.betterThan(.cellularUnknown))
	}

	func testConnectionTypeBetterThanCellularUnknownOverUnknown() {
		XCTAssertTrue(ConnectionType.cellularUnknown.betterThan(.unknown))
	}

	func testConnectionTypeBetterThanUnknownOverOffline() {
		XCTAssertTrue(ConnectionType.unknown.betterThan(.offline))
	}

	func testConnectionTypeBetterThanOfflineIsNotBetterThanAnything() {
		XCTAssertFalse(ConnectionType.offline.betterThan(.unknown))
		XCTAssertFalse(ConnectionType.offline.betterThan(.wifi))
	}

	func testConnectionTypeBetterThanIsNotReflexive() {
		XCTAssertFalse(ConnectionType.wifi.betterThan(.wifi))
		XCTAssertFalse(ConnectionType.cellular4g.betterThan(.cellular4g))
	}

	// MARK: - getTechnologyMap

	func testGetTechnologyMapContainsBaselineEntries() {
		let map = getTechnologyMap()
		XCTAssertEqual(map[CTRadioAccessTechnologyGPRS], .cellular2g)
		XCTAssertEqual(map[CTRadioAccessTechnologyEdge], .cellular2g)
		XCTAssertEqual(map[CTRadioAccessTechnologyCDMA1x], .cellular2g)
		XCTAssertEqual(map[CTRadioAccessTechnologyWCDMA], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyHSDPA], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyHSUPA], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyCDMAEVDORev0], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyCDMAEVDORevA], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyCDMAEVDORevB], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyeHRPD], .cellular3g)
		XCTAssertEqual(map[CTRadioAccessTechnologyLTE], .cellular4g)
	}

	func testGetTechnologyMapContains5gOnIOS141() {
		let map = getTechnologyMap()
		if #available(iOS 14.1, *) {
			XCTAssertEqual(map[CTRadioAccessTechnologyNRNSA], .cellular5g)
			XCTAssertEqual(map[CTRadioAccessTechnologyNR], .cellular5g)
		}
	}

	func testTechnologyMapGlobalConstantIsPopulated() {
		XCTAssertFalse(technologyMap.isEmpty)
	}

	// MARK: - getNetworkType

	func testGetNetworkTypeReturnsAValue() {
		// Exercises whichever branch the simulator happens to be in.
		// Acceptable outcomes include any ConnectionType case.
		let value = getNetworkType()
		let allowed: Set<String> = [
			"offline", "cellular_unknown", "cellular_2g", "cellular_3g",
			"cellular_4g", "cellular_5g", "wifi", "unknown",
		]
		XCTAssertTrue(allowed.contains(value.stringValue))
	}

	// MARK: - DeviceType

	func testDeviceTypePhoneStringValue() {
		XCTAssertEqual(DeviceType.phone.stringValue, "phone")
	}

	func testDeviceTypeTabletStringValue() {
		XCTAssertEqual(DeviceType.tablet.stringValue, "tablet")
	}

	// MARK: - DeviceInfo init

	func testDeviceInfoDefaultInit() {
		let info = DeviceInfo()
		XCTAssertNil(info.idfv)
		XCTAssertEqual(info.name, "")
		XCTAssertEqual(info.model, "")
		XCTAssertEqual(info.product, "")
		XCTAssertEqual(info.type, .phone)
		XCTAssertEqual(info.osVersion, "")
		XCTAssertEqual(info.osName, "")
		XCTAssertEqual(info.displayWidth, 0)
		XCTAssertEqual(info.displayHeight, 0)
	}

	func testDeviceInfoExplicitInit() {
		let idfv = StringID()
		let info = DeviceInfo(
			idfv: idfv,
			name: "n",
			model: "m",
			product: "p",
			type: .tablet,
			osVersion: "1.0",
			osName: "iOS",
			displayWidth: 100,
			displayHeight: 200
		)
		XCTAssertEqual(info.idfv, idfv)
		XCTAssertEqual(info.name, "n")
		XCTAssertEqual(info.model, "m")
		XCTAssertEqual(info.product, "p")
		XCTAssertEqual(info.type, .tablet)
		XCTAssertEqual(info.osVersion, "1.0")
		XCTAssertEqual(info.osName, "iOS")
		XCTAssertEqual(info.displayWidth, 100)
		XCTAssertEqual(info.displayHeight, 200)
	}

	func testDeviceInfoInitWithIdfvProviderPopulatesFields() {
		let idfv = StringID()
		let provider = StubIdfvProvider(idfv: idfv)
		let info = DeviceInfo(idfvProvider: provider)

		XCTAssertEqual(info.idfv, idfv)
		XCTAssertEqual(info.name, UIDevice.current.name)
		XCTAssertEqual(info.osVersion, UIDevice.current.systemVersion)
		XCTAssertEqual(info.osName, UIDevice.current.systemName)
		XCTAssertEqual(info.product, UIDevice.current.model)
		XCTAssertNotEqual(info.model, "")
		XCTAssertEqual(info.displayWidth, Int(UIScreen.main.bounds.width))
		XCTAssertEqual(info.displayHeight, Int(UIScreen.main.bounds.height))

		// Type reflects current device idiom; both branches are covered across simulator runs.
		let expectedType: DeviceType = UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .phone
		XCTAssertEqual(info.type, expectedType)
	}

	func testDeviceInfoInitWithNilIdfv() {
		let provider = StubIdfvProvider(idfv: nil)
		let info = DeviceInfo(idfvProvider: provider)
		XCTAssertNil(info.idfv)
	}
}

private struct StubIdfvProvider: AdTrackingProvider {
	let idfv: StringID?
	func provideIDFA() -> StringID? { nil }
	func provideIDFV() -> StringID? { idfv }
	func requestTrackingAuthorization(requester: AdTrackingPermissionRequester, _ onAuthorized: @escaping (Bool) -> Void) {
		onAuthorized(false)
	}
	func setLogger(_ logger: Logger) {}
}
