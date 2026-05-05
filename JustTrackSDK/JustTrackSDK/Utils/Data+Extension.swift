import Compression
import Foundation

extension Data {
	func gziped() -> Data? {
		guard let deflatedData = deflated() else {
			return nil
		}

		let now = UInt32(Date().timeIntervalSince1970)
		let crc32 = crc32Coder.crc32(self)
		let size = UInt32(count) & UInt32(0xFFFF_FFFF)

		let header: [UInt8] = [
			0x1f,  // magic number 1
			0x8b,  // magic number 2
			8,  // deflate compression
			0,  // no flags set
			UInt8(now & 0xFF),  // 32 bit little endian modification time
			UInt8((now >> 8) & 0xFF),
			UInt8((now >> 16) & 0xFF),
			UInt8((now >> 24) & 0xFF),
			0,  // neither best nor fastest compression
			255,  // unknown OS
		]
		let trailer: [UInt8] = [
			UInt8(crc32 & 0xFF),
			UInt8((crc32 >> 8) & 0xFF),
			UInt8((crc32 >> 16) & 0xFF),
			UInt8((crc32 >> 24) & 0xFF),
			UInt8(size & 0xFF),
			UInt8((size >> 8) & 0xFF),
			UInt8((size >> 16) & 0xFF),
			UInt8((size >> 24) & 0xFF),
		]

		var result = Data(capacity: 10 + deflatedData.count + 8)
		result.append(contentsOf: header)
		result.append(deflatedData)
		result.append(contentsOf: trailer)
		return result
	}

	func deflated() -> Data? {
		withUnsafeBytes { dataBufferRawPtr in
			let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
			defer { destinationBuffer.deallocate() }
			let algorithm = COMPRESSION_ZLIB

			let dataBufferPtr = dataBufferRawPtr.bindMemory(to: UInt8.self)
			guard let dataPtr = dataBufferPtr.baseAddress else {
				return nil
			}

			let compressedSize = compression_encode_buffer(destinationBuffer, count, dataPtr, count, nil, algorithm)

			if compressedSize == 0 {
				return nil
			}

			return Data(bytes: destinationBuffer, count: compressedSize)
		}
	}

	func gunziped() -> Data? {
		guard count >= 18, self[0] == 0x1f, self[1] == 0x8b, self[2] == 8 else { return nil }

		let compressedData = self[10..<(count - 8)]

		return compressedData.withUnsafeBytes { compressedBufferRawPtr in
			let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: compressedData.count * 4)
			defer { destinationBuffer.deallocate() }
			let algorithm = COMPRESSION_ZLIB

			let compressedBufferPtr = compressedBufferRawPtr.bindMemory(to: UInt8.self)
			guard let compressedPtr = compressedBufferPtr.baseAddress else { return nil }

			let decompressedSize = compression_decode_buffer(
				destinationBuffer,
				compressedData.count * 4,
				compressedPtr,
				compressedData.count,
				nil,
				algorithm
			)

			if decompressedSize == 0 { return nil }

			return Data(bytes: destinationBuffer, count: decompressedSize)
		}
	}
}

private let crc32Coder = CRC32Coder()

struct CRC32Coder {
	private let table: [UInt32]

	init() {
		var table: [UInt32] = []

		for n in 0..<256 {
			var c = UInt32(n)
			for _ in 0..<8 {
				if c & 1 != 0 {
					c = 0xedb8_8320 ^ (c >> 1)
				} else {
					c = c >> 1
				}
			}
			table.append(c)
		}

		self.table = table
	}

	func crc32(_ data: Data) -> UInt32 {
		var c: UInt32 = 0 ^ 0xffff_ffff

		for b in data {
			c = table[Int(UInt8(c & 0xFF) ^ b)] ^ (c >> 8)
		}

		return c ^ 0xffff_ffff
	}
}
