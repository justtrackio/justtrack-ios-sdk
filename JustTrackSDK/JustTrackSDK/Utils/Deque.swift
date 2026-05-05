import Foundation

final class Deque<T> {
	private var buffer: [T?]
	private var range: (Int, Int)?

	var isEmpty: Bool {
		range == nil
	}

	var count: Int {
		guard let range = range else { return 0 }
		let start = range.0
		var end = range.1
		if end < start {
			end += buffer.count
		}

		return end - start + 1
	}

	init(initialCapacity: Int) {
		buffer = Array(repeating: nil, count: initialCapacity)
		range = nil
	}

	func peekFirst() -> T? {
		guard let range = range else {
			return nil
		}

		return buffer[range.0]
	}

	func peekLast() -> T? {
		guard let range = range else {
			return nil
		}

		return buffer[range.1]
	}

	func removeFirst() -> T? {
		guard let range = range else {
			return nil
		}

		let result = buffer[range.0]
		buffer[range.0] = nil

		if range.0 == range.1 {
			self.range = nil
		} else {
			let newFirst = (range.0 + 1) % buffer.count
			self.range = (newFirst, range.1)
		}

		return result
	}

	func removeLast() -> T? {
		guard let range = range else {
			return nil
		}

		let result = buffer[range.1]
		buffer[range.1] = nil

		if range.0 == range.1 {
			self.range = nil
		} else {
			let newEnd = (range.1 - 1 + buffer.count) % buffer.count
			self.range = (range.0, newEnd)
		}

		return result
	}

	func addFirst(_ t: T) {
		checkGrow()

		if let range {
			let newFirst = (range.0 - 1 + buffer.count) % buffer.count
			buffer[newFirst] = t
			self.range = (newFirst, range.1)
		} else {
			// array is empty
			buffer[0] = t
			self.range = (0, 0)
		}
	}

	func addLast(_ t: T) {
		checkGrow()

		if let range {
			let newLast = (range.1 + 1) % buffer.count
			buffer[newLast] = t
			self.range = (range.0, newLast)
		} else {
			// array is empty
			buffer[0] = t
			self.range = (0, 0)
		}
	}

	private func checkGrow() {
		guard let range = self.range else { return }
		let nextLast = (range.1 + 1) % buffer.count
		if nextLast == range.0 {
			// the whole array is full, we need to grow it to get some space again
			grow(start: range.0)
		}
	}

	private func grow(start: Int) {
		var newBuffer = [T?](repeating: nil, count: buffer.count * 2)
		for i in 0..<buffer.count {
			let idx = (start + i) % buffer.count
			newBuffer[i] = buffer[idx]
			buffer[idx] = nil
		}

		self.range = (0, buffer.count - 1)
		buffer = newBuffer
	}
}
