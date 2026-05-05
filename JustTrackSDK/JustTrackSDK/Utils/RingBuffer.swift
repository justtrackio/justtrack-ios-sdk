struct RingBuffer<T>: Sequence {
	let capacity: Int

	var count: Int {
		isFull ? capacity : (writeIndex - readIndex + capacity) % capacity
	}

	var isEmpty: Bool {
		buffer[readIndex] == nil
	}

	var isFull: Bool {
		readIndex == writeIndex && !isEmpty
	}

	private var buffer: [T?]
	private var readIndex = 0
	private var writeIndex = 0

	init(capacity: Int) {
		self.capacity = Swift.max(1, capacity)
		self.buffer = [T?](repeating: nil, count: self.capacity)
	}

	mutating func write(_ element: T) {
		if isFull {
			readIndex = (readIndex + 1) % capacity
		}
		buffer[writeIndex] = element
		writeIndex = (writeIndex + 1) % capacity
	}

	mutating func read() -> T? {
		if isEmpty { return nil }
		let element = buffer[readIndex]
		buffer[readIndex] = nil
		readIndex = (readIndex + 1) % capacity
		return element
	}

	func elements(reversed: Bool = false) -> [T] {
		return reversed ? Array(self).reversed() : Array(self)
	}

	func makeIterator() -> Iterator {
		return Iterator(self)
	}
}

extension RingBuffer {
	struct Iterator: IteratorProtocol {
		private var readIndex: Int
		private var remaining: Int
		private var buffer: [T?]

		init(_ ringBuffer: RingBuffer) {
			self.readIndex = ringBuffer.readIndex
			self.remaining = ringBuffer.count
			self.buffer = ringBuffer.buffer
		}

		mutating func next() -> T? {
			guard remaining > 0 else { return nil }
			let element = buffer[readIndex]
			readIndex = (readIndex + 1) % buffer.count
			remaining -= 1
			return element
		}
	}
}
