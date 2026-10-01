import XCTest

@testable import JustTrackSDK

// MARK: - LoggerFieldsImpl Tests

final class LoggerFieldsImplTests: XCTestCase {
	func testEmptyFieldsBuilderReturnsEmptyDictionary() {
		let builder = LoggerFieldsImpl()
		XCTAssertEqual(builder.getFields(), [:])
	}

	func testWithStringValueSetsField() {
		let fields = LoggerFieldsImpl().with("key", "value").getFields()
		XCTAssertEqual(fields["key"], "value")
	}

	func testWithNilStringClearsField() {
		let builder = LoggerFieldsImpl(fields: ["key": "old"])
		_ = builder.with("key", nil as String?)
		// nil value is written as-is (fields[field] = nil removes the key)
		XCTAssertNil(builder.getFields()["key"])
	}

	func testWithErrorValueSetsDescription() {
		let error = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "boom"])
		let fields = LoggerFieldsImpl().with("err", error).getFields()
		XCTAssertNotNil(fields["err"])
		XCTAssertTrue(fields["err"]!.contains("42"))
	}

	func testWithNilErrorLeavesFieldAbsent() {
		let fields = LoggerFieldsImpl().with("err", nil as Error?).getFields()
		XCTAssertNil(fields["err"])
	}

	func testWithBoolTrue() {
		let fields = LoggerFieldsImpl().with("flag", true).getFields()
		XCTAssertEqual(fields["flag"], "true")
	}

	func testWithBoolFalse() {
		let fields = LoggerFieldsImpl().with("flag", false).getFields()
		XCTAssertEqual(fields["flag"], "false")
	}

	func testWithNilBoolLeavesFieldAbsent() {
		let fields = LoggerFieldsImpl().with("flag", nil as Bool?).getFields()
		XCTAssertNil(fields["flag"])
	}

	func testWithCharacter() {
		let fields = LoggerFieldsImpl().with("ch", Character("Z")).getFields()
		XCTAssertEqual(fields["ch"], "Z")
	}

	func testWithNilCharacterLeavesFieldAbsent() {
		let fields = LoggerFieldsImpl().with("ch", nil as Character?).getFields()
		XCTAssertNil(fields["ch"])
	}

	func testWithUInt8() {
		let fields = LoggerFieldsImpl().with("n", UInt8(255)).getFields()
		XCTAssertEqual(fields["n"], "255")
	}

	func testWithInt8() {
		let fields = LoggerFieldsImpl().with("n", Int8(-128)).getFields()
		XCTAssertEqual(fields["n"], "-128")
	}

	func testWithUInt16() {
		let fields = LoggerFieldsImpl().with("n", UInt16(65535)).getFields()
		XCTAssertEqual(fields["n"], "65535")
	}

	func testWithInt16() {
		let fields = LoggerFieldsImpl().with("n", Int16(-32768)).getFields()
		XCTAssertEqual(fields["n"], "-32768")
	}

	func testWithUInt32() {
		let fields = LoggerFieldsImpl().with("n", UInt32(4_294_967_295)).getFields()
		XCTAssertEqual(fields["n"], "4294967295")
	}

	func testWithInt32() {
		let fields = LoggerFieldsImpl().with("n", Int32(-2_147_483_648)).getFields()
		XCTAssertEqual(fields["n"], "-2147483648")
	}

	func testWithUInt64() {
		let fields = LoggerFieldsImpl().with("n", UInt64(1_000_000)).getFields()
		XCTAssertEqual(fields["n"], "1000000")
	}

	func testWithInt64() {
		let fields = LoggerFieldsImpl().with("n", Int64(-1)).getFields()
		XCTAssertEqual(fields["n"], "-1")
	}

	func testWithUInt() {
		let fields = LoggerFieldsImpl().with("n", UInt(42)).getFields()
		XCTAssertEqual(fields["n"], "42")
	}

	func testWithInt() {
		let fields = LoggerFieldsImpl().with("n", Int(-7)).getFields()
		XCTAssertEqual(fields["n"], "-7")
	}

	func testWithFloat() {
		let fields = LoggerFieldsImpl().with("n", Float(1.5)).getFields()
		XCTAssertEqual(fields["n"], "1.5")
	}

	func testWithDouble() {
		let fields = LoggerFieldsImpl().with("n", Double(3.14)).getFields()
		XCTAssertNotNil(fields["n"])
	}

	func testWithDate() {
		// Date value produces a non-empty milliseconds string
		let fields = LoggerFieldsImpl().with("ts", Date(timeIntervalSince1970: 0)).getFields()
		XCTAssertNotNil(fields["ts"])
		XCTAssertFalse(fields["ts"]!.isEmpty)
	}

	func testWithNilDateLeavesFieldAbsent() {
		let fields = LoggerFieldsImpl().with("ts", nil as Date?).getFields()
		XCTAssertNil(fields["ts"])
	}

	func testChainingProducesAllFields() {
		let fields = LoggerFieldsImpl()
			.with("a", "1")
			.with("b", "2")
			.with("c", "3")
			.getFields()
		XCTAssertEqual(fields.count, 3)
		XCTAssertEqual(fields["a"], "1")
		XCTAssertEqual(fields["b"], "2")
		XCTAssertEqual(fields["c"], "3")
	}
}

// MARK: - MetricUnit Tests

final class MetricUnitTests: XCTestCase {
	func testGetUnitCount() { XCTAssertEqual(MetricUnit.count.getUnit(), "Count") }
	func testGetUnitSeconds() { XCTAssertEqual(MetricUnit.seconds.getUnit(), "Seconds") }
	func testGetUnitMilliseconds() { XCTAssertEqual(MetricUnit.milliseconds.getUnit(), "Milliseconds") }
	func testGetUnitCountAverage() { XCTAssertEqual(MetricUnit.countAverage.getUnit(), "UnitCountAverage") }
	func testGetUnitCountMaximum() { XCTAssertEqual(MetricUnit.countMaximum.getUnit(), "UnitCountMaximum") }
	func testGetUnitCountMinimum() { XCTAssertEqual(MetricUnit.countMinimum.getUnit(), "UnitCountMinimum") }
	func testGetUnitSecondsAverage() { XCTAssertEqual(MetricUnit.secondsAverage.getUnit(), "UnitSecondsAverage") }
	func testGetUnitSecondsMaximum() { XCTAssertEqual(MetricUnit.secondsMaximum.getUnit(), "UnitSecondsMaximum") }
	func testGetUnitSecondsMinimum() { XCTAssertEqual(MetricUnit.secondsMinimum.getUnit(), "UnitSecondsMinimum") }
	func testGetUnitMillisecondsAverage() { XCTAssertEqual(MetricUnit.millisecondsAverage.getUnit(), "UnitMillisecondsAverage") }
	func testGetUnitMillisecondsMaximum() { XCTAssertEqual(MetricUnit.millisecondsMaximum.getUnit(), "UnitMillisecondsMaximum") }
	func testGetUnitMillisecondsMinimum() { XCTAssertEqual(MetricUnit.millisecondsMinimum.getUnit(), "UnitMillisecondsMinimum") }
}

// MARK: - Metric Tests

final class MetricTests: XCTestCase {
	func testDefaultInitUsesCountUnit() {
		let metric = Metric(metric: "my_metric")
		XCTAssertEqual(metric.metric, "my_metric")
		XCTAssertEqual(metric.unit, .count)
		XCTAssertEqual(metric.defaultDimensions, [:])
	}

	func testInitWithUnit() {
		let metric = Metric(metric: "latency", unit: .milliseconds)
		XCTAssertEqual(metric.unit, .milliseconds)
	}

	func testInitWithDefaultDimensions() {
		let metric = Metric(metric: "req", defaultDimensions: ["env": "prod"], unit: .count)
		XCTAssertEqual(metric.defaultDimensions["env"], "prod")
	}

	func testGetFieldsReturnsDefaultDimensions() {
		let metric = Metric(metric: "req", defaultDimensions: ["region": "us-east"], unit: .count)
		XCTAssertEqual(metric.getFields()["region"], "us-east")
	}
}

// MARK: - Error.justTrackGetErrorDescription Tests

final class ErrorDescriptionTests: XCTestCase {
	func testJustTrackGetErrorDescriptionContainsDomain() {
		let error = NSError(domain: "com.example.domain", code: 99)
		let desc = error.justTrackGetErrorDescription()
		XCTAssertTrue(desc.contains("com.example.domain"))
	}

	func testJustTrackGetErrorDescriptionContainsCode() {
		let error = NSError(domain: "d", code: 404)
		let desc = error.justTrackGetErrorDescription()
		XCTAssertTrue(desc.contains("404"))
	}
}

// MARK: - CompositeLogger Tests

final class CompositeLoggerTests: XCTestCase {
	private var mock1: MockLogger!
	private var mock2: MockLogger!
	private var composite: CompositeLogger!

	override func setUp() {
		super.setUp()
		mock1 = MockLogger()
		mock2 = MockLogger()
		composite = CompositeLogger(loggers: [mock1, mock2])
	}

	func testDebugForwardsToAllLoggers() {
		composite.debug("d", [] as [LoggerFields])
		XCTAssertEqual(mock1.entries.count, 1)
		XCTAssertEqual(mock2.entries.count, 1)
	}

	func testInfoForwardsToAllLoggers() {
		composite.info("i", [] as [LoggerFields])
		XCTAssertEqual(mock1.entries[0].level, .info)
		XCTAssertEqual(mock2.entries[0].level, .info)
	}

	func testWarnForwardsToAllLoggers() {
		composite.warn("w", [] as [LoggerFields])
		XCTAssertEqual(mock1.entries[0].level, .warn)
		XCTAssertEqual(mock2.entries[0].level, .warn)
	}

	func testErrorForwardsToAllLoggers() {
		composite.error("e", [] as [LoggerFields])
		XCTAssertEqual(mock1.entries[0].level, .error)
		XCTAssertEqual(mock2.entries[0].level, .error)
	}

	func testErrorWithExceptionForwardsToAllLoggers() {
		let err = NSError(domain: "d", code: 1)
		composite.error("e", err, [] as [LoggerFields])
		XCTAssertNotNil(mock1.entries[0].exception)
		XCTAssertNotNil(mock2.entries[0].exception)
	}

	func testVariadicErrorWithExceptionForwardsToArrayOverload() {
		// Exercises the variadic `error(_:_:_:)` default protocol-extension forwarder which
		// repacks the fields into the array overload.
		let err = NSError(domain: "d", code: 7)
		let field = LoggerFieldsImpl().with("k", "v")

		composite.error("variadic", err, field)

		XCTAssertEqual(mock1.entries[0].level, .error)
		XCTAssertNotNil(mock1.entries[0].exception)
		XCTAssertEqual(mock2.entries[0].level, .error)
		XCTAssertNotNil(mock2.entries[0].exception)
	}

	func testPublishMetricForwardsToAllLoggers() {
		composite.publishMetric(Metric(metric: "m"), 5.0, [] as [LoggerFields])
		XCTAssertEqual(mock1.entries[0].level, .metric)
		XCTAssertEqual(mock2.entries[0].level, .metric)
	}

	func testEmptyCompositeDoesNotCrash() {
		let empty = CompositeLogger(loggers: [])
		empty.debug("x", [] as [LoggerFields])
		// no assertion needed — just must not crash
	}
}

// MARK: - IdleLogger Tests

final class IdleLoggerTests: XCTestCase {
	private let idle = IdleLogger()

	func testDebugDoesNothing() {
		idle.debug("msg", [] as [LoggerFields])
		// must not crash; no output to verify
	}

	func testInfoDoesNothing() {
		idle.info("msg", [] as [LoggerFields])
	}

	func testWarnDoesNothing() {
		idle.warn("msg", [] as [LoggerFields])
	}

	func testErrorDoesNothing() {
		idle.error("msg", [] as [LoggerFields])
	}

	func testErrorWithExceptionDoesNothing() {
		idle.error("msg", NSError(domain: "d", code: 0), [] as [LoggerFields])
	}

	func testPublishMetricDoesNothing() {
		idle.publishMetric(Metric(metric: "m"), 1.0, [] as [LoggerFields])
	}
}
