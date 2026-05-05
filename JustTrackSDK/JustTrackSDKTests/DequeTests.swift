import XCTest

@testable import JustTrackSDK

class DequeTests: XCTestCase {
	func testDequeSimple() {
		let queue = Deque<Int>(initialCapacity: 4)
		queue.addLast(1)
		queue.addLast(2)
		queue.addLast(3)
		XCTAssertEqual(1, queue.peekFirst())
		XCTAssertEqual(3, queue.peekLast())

		XCTAssertEqual(1, queue.removeFirst())
		XCTAssertEqual(3, queue.removeLast())
		XCTAssertEqual(2, queue.removeFirst())

		assertEmpty(queue)
	}

	func testDequeGrow() {
		let queue = Deque<Int>(initialCapacity: 4)

		for i in 1...6 {
			queue.addLast(i)
		}
		XCTAssertEqual(6, queue.count)

		for i in (1...6).reversed() {
			XCTAssertEqual(i, queue.peekLast())
			XCTAssertEqual(i, queue.removeLast())
		}

		assertEmpty(queue)
	}

	func testDequeReverse() {
		let queue = Deque<Int>(initialCapacity: 2)
		queue.addFirst(1)
		queue.addFirst(2)
		queue.addFirst(3)
		XCTAssertEqual(1, queue.removeLast())
		XCTAssertEqual(2, queue.removeLast())
		XCTAssertEqual(3, queue.removeLast())

		assertEmpty(queue)
	}

	func testDequeWrapAround() {
		let queue = Deque<Int>(initialCapacity: 8)

		for i in 1...6 {
			queue.addLast(i)
		}

		for i in 1...4 {
			XCTAssertEqual(i, queue.removeFirst())
		}

		XCTAssertEqual(2, queue.count)

		for i in 7...10 {
			queue.addLast(i)
		}

		XCTAssertEqual(6, queue.count)

		for i in 5...10 {
			XCTAssertEqual(i, queue.removeFirst())
		}

		assertEmpty(queue)
	}

	func testDequeWrapAroundReversed() {
		let queue = Deque<Int>(initialCapacity: 16)

		for i in 1...6 {
			queue.addLast(i)
		}

		for i in 1...2 {
			XCTAssertEqual(i, queue.removeFirst())
		}

		XCTAssertEqual(4, queue.count)

		for i in (-3...2).reversed() {
			queue.addFirst(i)
		}

		XCTAssertEqual(10, queue.count)

		for i in (-3...6).reversed() {
			XCTAssertEqual(i, queue.removeLast())
		}

		assertEmpty(queue)
	}

	func assertEmpty(_ queue: Deque<Int>) {
		XCTAssertNil(queue.peekFirst())
		XCTAssertNil(queue.peekLast())
		XCTAssertNil(queue.removeFirst())
		XCTAssertNil(queue.removeLast())
		XCTAssertEqual(0, queue.count)
		XCTAssertTrue(queue.isEmpty)
	}
}
