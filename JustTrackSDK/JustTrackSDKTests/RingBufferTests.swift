import XCTest

@testable import JustTrackSDK

final class RingBufferTests: XCTestCase {
	func testWriteAndRead() {
		var ringBuffer = RingBuffer<Int>(capacity: 3)
		XCTAssertNil(ringBuffer.read())

		ringBuffer.write(1)
		ringBuffer.write(2)
		XCTAssertEqual(ringBuffer.read(), 1)
		XCTAssertEqual(ringBuffer.read(), 2)

		XCTAssertNil(ringBuffer.read())
	}

	func testOverwrite() {
		var ringBuffer = RingBuffer<Int>(capacity: 2)

		ringBuffer.write(1)
		ringBuffer.write(2)
		ringBuffer.write(3)
		XCTAssertEqual(ringBuffer.read(), 2)
		XCTAssertEqual(ringBuffer.read(), 3)

		XCTAssertNil(ringBuffer.read())
	}

	func testIsEmpty() {
		var ringBuffer = RingBuffer<Int>(capacity: 1)
		XCTAssertTrue(ringBuffer.isEmpty)

		ringBuffer.write(1)
		XCTAssertFalse(ringBuffer.isEmpty)

		_ = ringBuffer.read()
		XCTAssertTrue(ringBuffer.isEmpty)
	}

	func testIsFull() {
		var ringBuffer = RingBuffer<Int>(capacity: 2)
		XCTAssertFalse(ringBuffer.isFull)

		ringBuffer.write(1)
		XCTAssertFalse(ringBuffer.isFull)
		ringBuffer.write(2)
		XCTAssertTrue(ringBuffer.isFull)
		ringBuffer.write(3)
		XCTAssertTrue(ringBuffer.isFull)

		_ = ringBuffer.read()
		XCTAssertFalse(ringBuffer.isFull)
	}

	func testCapacity() {
		for capacity in [(-100, 1), (-1, 1), (0, 1), (1, 1), (2, 2), (41, 41)] as [(actual: Int, expected: Int)] {
			var ringBuffer = RingBuffer<Int>(capacity: capacity.actual)
			ringBuffer.write(1)
			XCTAssertEqual(ringBuffer.capacity, capacity.expected)
		}
	}

	func testElements() {
		for test in [
			([], []),
			([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [12]),
			([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [10, 11, 12]),
		] as [(input: [Int], elements: [Int])] {
			var ringBuffer = RingBuffer<Int>(capacity: test.elements.count)

			for number in test.input {
				ringBuffer.write(number)
			}

			XCTAssertEqual(ringBuffer.elements(), test.elements)
		}
	}

	func testElementsWhenReversed() {
		for test in [
			([], []),
			([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [12]),
			([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [12, 11, 10]),
		] as [(input: [Int], elements: [Int])] {
			var ringBuffer = RingBuffer<Int>(capacity: test.elements.count)

			for number in test.input {
				ringBuffer.write(number)
			}

			XCTAssertEqual(ringBuffer.elements(reversed: true), test.elements)
		}
	}
}
