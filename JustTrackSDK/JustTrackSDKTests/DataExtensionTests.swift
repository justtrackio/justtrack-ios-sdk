import XCTest

@testable import JustTrackSDK

final class DataExtensionTests: XCTestCase {
	// A string long enough that deflated() succeeds (compression_encode_buffer needs
	// the compressed size to fit within `count` bytes as destination capacity).
	private let compressibleData = Data(
		"The quick brown fox jumps over the lazy dog. The quick brown fox jumps.".utf8
	)

	// MARK: - deflated()

	func testDeflatedProducesNonEmptyOutputForNonEmptyInput() {
		XCTAssertNotNil(compressibleData.deflated())
	}

	func testDeflatedReturnsNilForEmptyData() {
		// compression_encode_buffer returns 0 for empty input
		XCTAssertNil(Data().deflated())
	}

	func testDeflatedOutputIsNonNilForLargeRepetitiveInput() {
		// Large repetitive input deflates well inside the capacity=count limit
		let repeated = Data(repeating: 0xAB, count: 1000)
		XCTAssertNotNil(repeated.deflated())
	}

	// MARK: - gziped()

	func testGzipedReturnsNilForEmptyData() {
		XCTAssertNil(Data().gziped())
	}

	func testGzipedHasCorrectMagicNumber() {
		guard let gzipped = compressibleData.gziped() else {
			XCTFail("gziped returned nil")
			return
		}
		XCTAssertEqual(gzipped[0], 0x1F)
		XCTAssertEqual(gzipped[1], 0x8B)
	}

	func testGzipedHasDeflateCompressionMethod() {
		guard let gzipped = compressibleData.gziped() else {
			XCTFail("gziped returned nil")
			return
		}
		XCTAssertEqual(gzipped[2], 8)
	}

	func testGzipedSizeEqualsHeaderPlusDeflatedPlusTrailer() {
		guard let gzipped = compressibleData.gziped(),
			let deflated = compressibleData.deflated()
		else {
			XCTFail("gziped or deflated returned nil")
			return
		}
		// total = 10 (header) + deflated.count + 8 (trailer)
		XCTAssertEqual(gzipped.count, 10 + deflated.count + 8)
	}

	// MARK: - gunziped()

	func testGunzipedRoundTrip() {
		// Use compressibleData — compressed * 4 is comfortably larger than original
		guard let gzipped = compressibleData.gziped() else {
			XCTFail("gziped returned nil")
			return
		}
		XCTAssertEqual(gzipped.gunziped(), compressibleData)
	}

	func testGunzipedRoundTripWithAlternativeInput() {
		// Use a longer text string to ensure deflated() succeeds (capacity=count constraint)
		let original = Data(
			"Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump!".utf8
		)
		guard let gzipped = original.gziped() else {
			XCTFail("gziped returned nil")
			return
		}
		XCTAssertEqual(gzipped.gunziped(), original)
	}

	func testGunzipedReturnsNilForTooShortData() {
		// Needs at least 18 bytes
		let short = Data(repeating: 0x1F, count: 17)
		XCTAssertNil(short.gunziped())
	}

	func testGunzipedReturnsNilForWrongFirstMagicByte() {
		var bytes = [UInt8](repeating: 0, count: 20)
		bytes[0] = 0x00  // wrong — should be 0x1F
		bytes[1] = 0x8B
		bytes[2] = 8
		XCTAssertNil(Data(bytes).gunziped())
	}

	func testGunzipedReturnsNilForWrongSecondMagicByte() {
		var bytes = [UInt8](repeating: 0, count: 20)
		bytes[0] = 0x1F
		bytes[1] = 0x00  // wrong — should be 0x8B
		bytes[2] = 8
		XCTAssertNil(Data(bytes).gunziped())
	}

	func testGunzipedReturnsNilForWrongCompressionMethod() {
		var bytes = [UInt8](repeating: 0, count: 20)
		bytes[0] = 0x1F
		bytes[1] = 0x8B
		bytes[2] = 9  // wrong — deflate is 8
		XCTAssertNil(Data(bytes).gunziped())
	}

	// MARK: - CRC32Coder

	func testCRC32KnownValue() {
		// CRC32("Hello") == 0xF7D18982 (verified independently)
		let coder = CRC32Coder()
		let result = coder.crc32(Data("Hello".utf8))
		XCTAssertEqual(result, 0xF7D1_8982)
	}

	func testCRC32EmptyDataIsZero() {
		let coder = CRC32Coder()
		XCTAssertEqual(coder.crc32(Data()), 0x0000_0000)
	}

	func testCRC32IsDeterministic() {
		let coder = CRC32Coder()
		let data = Data("repeatability check".utf8)
		XCTAssertEqual(coder.crc32(data), coder.crc32(data))
	}

	func testCRC32DifferentInputsProduceDifferentResults() {
		let coder = CRC32Coder()
		XCTAssertNotEqual(
			coder.crc32(Data("abc".utf8)),
			coder.crc32(Data("def".utf8))
		)
	}

	// MARK: - gzip trailer integrity

	func testGzipedTrailerContainsCorrectCRC32() {
		guard let gzipped = compressibleData.gziped() else {
			XCTFail("gziped returned nil")
			return
		}
		// CRC32 is stored little-endian at bytes [count-8 ..< count-4]
		let base = gzipped.startIndex
		let crcStart = gzipped.count - 8
		let storedCRC: UInt32 =
			UInt32(gzipped[base + crcStart]) | (UInt32(gzipped[base + crcStart + 1]) << 8) | (UInt32(gzipped[base + crcStart + 2]) << 16) | (UInt32(gzipped[base + crcStart + 3]) << 24)
		let expectedCRC = CRC32Coder().crc32(compressibleData)
		XCTAssertEqual(storedCRC, expectedCRC)
	}

	func testGzipedTrailerContainsCorrectInputSize() {
		guard let gzipped = compressibleData.gziped() else {
			XCTFail("gziped returned nil")
			return
		}
		// Size is stored little-endian in the last 4 bytes
		let base = gzipped.startIndex
		let sizeStart = gzipped.count - 4
		let storedSize: UInt32 =
			UInt32(gzipped[base + sizeStart]) | (UInt32(gzipped[base + sizeStart + 1]) << 8) | (UInt32(gzipped[base + sizeStart + 2]) << 16) | (UInt32(gzipped[base + sizeStart + 3]) << 24)
		XCTAssertEqual(storedSize, UInt32(compressibleData.count))
	}
}
