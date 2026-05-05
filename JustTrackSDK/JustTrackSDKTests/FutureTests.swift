import Foundation
import XCTest

@testable import JustTrackSDK

struct TestError: Error, Equatable {
	public let errorCode: Int

	public init(_ errorCode: Int) {
		self.errorCode = errorCode
	}
}

final class FutureTests: XCTestCase {
	func testFutureResolve() {
		var called = false
		var errCalled = false
		let f1 = FutureImpl<Int>()
		f1.observe(using: {
			_ = $0.map({ (value: Int) -> Void in
				XCTAssertEqual(value, 42)
				called = true
			})
			_ = $0.mapError({ (err: Error) -> Error in
				errCalled = true
				return err
			})
		})
		_ = f1.resolve(42)
		XCTAssert(called)
		XCTAssert(!errCalled)
	}

	func testFutureAlreadyResolved() {
		var called = false
		var errCalled = false
		let f1 = FutureImpl<Int>(42)
		f1.observe(using: {
			_ = $0.map({ (value: Int) -> Void in
				XCTAssertEqual(value, 42)
				called = true
			})
			_ = $0.mapError({ (err: Error) -> Error in
				errCalled = true
				return err
			})
		})
		XCTAssert(called)
		XCTAssert(!errCalled)
	}

	func testFutureReject() {
		var called = false
		var errCalled = false
		let f1 = FutureImpl<Int>()
		let myError = TestError(42)
		f1.observe(using: {
			_ = $0.map({ (value: Int) -> Void in
				called = true
			})
			_ = $0.mapError({ (err: Error) -> Error in
				errCalled = true
				XCTAssertEqual(myError, err as! TestError)
				return err
			})
		})
		_ = f1.reject(myError)
		XCTAssert(!called)
		XCTAssert(errCalled)
	}

	func testFutureMany() {
		var resolved = 0
		var rejected = 0
		var futures = [FutureImpl<Int>]()

		for i in 0..<100 {
			let f = FutureImpl<Int>()
			let expectedVal = i
			f.observe(using: {
				_ = $0.map({ (value: Int) -> Void in
					resolved += 1
					XCTAssertEqual(expectedVal, value)
				})
				_ = $0.mapError({ (err: Error) -> Error in
					rejected += 1
					XCTAssertEqual(TestError(expectedVal), err as! TestError)
					return err
				})
			})
			futures += [f]
		}
		for i in 0..<100 {
			if i % 2 == 0 {
				_ = futures[i].resolve(i)
			} else {
				_ = futures[i].reject(TestError(i))
			}
		}
		XCTAssertEqual(50, resolved)
		XCTAssertEqual(50, rejected)
	}

	func testFutureRetriesSuccess() {
		var calls = 0
		let classifier = AttributionErrorClassifier()
		let f: Future<Int> = RetryingFuture(
			retries: 5,
			logger: LoggerImpl(),
			requestName: nil,
			classifier: classifier,
			for: {
				calls += 1
				if calls < 3 {
					return FutureImpl().reject(NetworkError.missingResponseData)
				}

				return FutureImpl(42).toFuture()
			}
		).toFuture()
		let expectation = self.expectation(description: #function)
		f.observe(using: { result in
			switch result {
			case .failure(let err):
				XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
			case .success(let value):
				XCTAssertEqual(42, value)
			}
			expectation.fulfill()
		})
		waitForExpectations(timeout: 10)
		XCTAssertEqual(3, calls)
	}

	func testFutureFixedRetriesSuccess() {
		var calls = 0
		let classifier = AttributionErrorClassifier()
		let f: Future<Int> = RetryingFuture(
			retryDelaySeconds: [0.1, 0.1, 100],
			logger: LoggerImpl(),
			requestName: nil,
			classifier: classifier,
			for: {
				calls += 1
				if calls < 3 {
					return FutureImpl().reject(NetworkError.missingResponseData)
				}

				return FutureImpl(42).toFuture()
			}
		).toFuture()
		let expectation = self.expectation(description: #function)
		f.observe(using: { result in
			switch result {
			case .failure(let err):
				XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
			case .success(let value):
				XCTAssertEqual(42, value)
			}
			expectation.fulfill()
		})
		waitForExpectations(timeout: 10)
		XCTAssertEqual(3, calls)
	}

	func testFutureRetriesFailure() {
		var calls = 0
		let classifier = AttributionErrorClassifier()
		let f: Future<Int> = RetryingFuture(
			retries: 5,
			logger: LoggerImpl(),
			requestName: nil,
			classifier: classifier,
			for: {
				calls += 1
				if calls < 30 {
					return FutureImpl().reject(NetworkError.missingResponseData)
				}

				return FutureImpl(42).toFuture()
			}
		).toFuture()
		let expectation = self.expectation(description: #function)
		f.observe(using: { result in
			switch result {
			case .failure(let err):
				guard let err = err as? NetworkError else {
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
					return
				}
				switch err {
				case .missingResponseData:
					XCTAssert(true)
				default:
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
				}
			case .success(let value):
				XCTFail("Unexpected success: \(value)")
			}
			expectation.fulfill()
		})
		waitForExpectations(timeout: 60)
		XCTAssertEqual(6, calls)
	}

	func testFutureFixedRetriesFailure() {
		var calls = 0
		let classifier = AttributionErrorClassifier()
		let f: Future<Int> = RetryingFuture(
			retryDelaySeconds: [0.1, 0.1, 0.1, 0.1, 0.1],
			logger: LoggerImpl(),
			requestName: nil,
			classifier: classifier,
			for: {
				calls += 1
				if calls < 30 {
					return FutureImpl().reject(NetworkError.missingResponseData)
				}

				return FutureImpl(42).toFuture()
			}
		).toFuture()
		let expectation = self.expectation(description: #function)
		f.observe(using: { result in
			switch result {
			case .failure(let err):
				guard let err = err as? NetworkError else {
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
					return
				}
				switch err {
				case .missingResponseData:
					XCTAssert(true)
				default:
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
				}
			case .success(let value):
				XCTFail("Unexpected success: \(value)")
			}
			expectation.fulfill()
		})
		waitForExpectations(timeout: 60)
		XCTAssertEqual(6, calls)
	}

	func testObserveWithTimeoutTimeout() {
		let f: FutureImpl<Int> = FutureImpl()
		let expectation = self.expectation(description: #function)
		f.observeWithTimeout(
			timeout: 1,
			using: { result in
				switch result {
				case .timeout:
					expectation.fulfill()
				case .success(let resultValue):
					XCTFail("Unexpected result value: \(resultValue)")
				case .failure(let err):
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
				}
			}
		)
		waitForExpectations(timeout: 3)
	}

	func testObserveWithTimeoutFulfilled() {
		let f: FutureImpl<Int> = FutureImpl()
		let expectation = self.expectation(description: #function)
		f.observeWithTimeout(
			timeout: 1,
			using: { result in
				switch result {
				case .timeout:
					XCTFail("Unexpected timeout")
				case .success(let resultValue):
					XCTAssertEqual(42, resultValue)
					expectation.fulfill()
				case .failure(let err):
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
				}
			}
		)
		_ = f.resolve(42)
		waitForExpectations(timeout: 1)
	}

	func testObserveWithTimeoutAlreadyFulfilled() {
		let f: FutureImpl<Int> = FutureImpl(42)
		var called = false
		f.observeWithTimeout(
			timeout: 1,
			using: { result in
				called = true
				switch result {
				case .timeout:
					XCTFail("Unexpected timeout")
				case .success(let resultValue):
					XCTAssertEqual(42, resultValue)
				case .failure(let err):
					XCTFail("Unexpected error: \(err.justTrackGetErrorDescription())")
				}
			}
		)
		XCTAssert(called)
	}

	func testIsFulfilledFalseAfterInit() {
		XCTAssertEqual(FutureImpl<Int>().isFulfilled, false)
		XCTAssertEqual(FutureImpl<Int>().toFuture().isFulfilled, false)
	}

	func testIsFulfilledTrueAfterFulfillWithResult() {
		XCTAssertEqual(FutureImpl<Int>(41).isFulfilled, true)
		XCTAssertEqual(FutureImpl<Int>(41).toFuture().isFulfilled, true)
	}

	func testIsFulfilledTrueAfterFulfillWithError() {
		let future = FutureImpl<Int>()
		_ = future.reject(FutureError.some)

		XCTAssertEqual(future.isFulfilled, true)
		XCTAssertEqual(future.toFuture().isFulfilled, true)
	}

	func testIsFulfilledAfterInitWhenTransformingFutureIsUsed() {
		XCTAssertEqual(
			TransformingFuture(FutureImpl<Int>().toFuture()) { _ in 41.0 }.toFuture().isFulfilled,
			false
		)

		XCTAssertEqual(
			TransformingFuture(FutureImpl<Int>(41).toFuture()) { _ in 41.0 }.toFuture().isFulfilled,
			true
		)

		XCTAssertEqual(
			TransformingFuture(FutureImpl<Int>().reject(FutureError.some)) { _ in 41.0 }.toFuture().isFulfilled,
			true
		)
	}

	func testPromiseIsResolvedOnDedicatedQueueWhenSpecified() {
		let queue = DispatchQueue(label: "dedicated-queue")
		queue.makeIdentifiable()
		let promise = FutureImpl<Int>()
		let promiseExpectation = expectation(description: "promise")
		let futureExpectation = expectation(description: "future")
		promise.observe(on: queue) { _ in
			XCTAssert(queue.isCurrent)
			promiseExpectation.fulfill()
		}
		promise.toFuture().observe(on: queue) { _ in
			XCTAssert(queue.isCurrent)
			futureExpectation.fulfill()
		}

		promise.resolve(41)

		waitForExpectations(timeout: 3)
	}

	func testPromiseIsRejectedOnDedicatedQueueWhenSpecified() {
		let queue = DispatchQueue(label: "dedicated-queue")
		queue.makeIdentifiable()
		let promise = FutureImpl<Int>()
		let promiseExpectation = expectation(description: "promise")
		let futureExpectation = expectation(description: "future")
		promise.observe(on: queue) { _ in
			XCTAssert(queue.isCurrent)
			promiseExpectation.fulfill()
		}
		promise.toFuture().observe(on: queue) { _ in
			XCTAssert(queue.isCurrent)
			futureExpectation.fulfill()
		}

		promise.reject(FutureError.some)

		waitForExpectations(timeout: 3)
	}

	func testPromiseWithTimeoutIsResolvedOnDedicatedQueueWhenSpecified() {
		let queue = DispatchQueue(label: "dedicated-queue")
		queue.makeIdentifiable()
		let promise = FutureImpl<Int>()
		let promiseExpectation = expectation(description: "promise")
		let futureExpectation = expectation(description: "future")
		promise.observeWithTimeout(on: queue, timeout: 12) { _ in
			XCTAssert(queue.isCurrent)
			promiseExpectation.fulfill()
		}
		promise.toFuture().observeWithTimeout(on: queue, timeout: 12) { _ in
			XCTAssert(queue.isCurrent)
			futureExpectation.fulfill()
		}

		promise.resolve(41)

		waitForExpectations(timeout: 3)
	}

	func testPromiseWithTimeoutIsRejectedOnDedicatedQueueWhenSpecified() {
		let queue = DispatchQueue(label: "dedicated-queue")
		queue.makeIdentifiable()
		let promise = FutureImpl<Int>()
		let promiseExpectation = expectation(description: "promise")
		let futureExpectation = expectation(description: "future")
		promise.observeWithTimeout(on: queue, timeout: 12) { _ in
			XCTAssert(queue.isCurrent)
			promiseExpectation.fulfill()
		}
		promise.toFuture().observeWithTimeout(on: queue, timeout: 12) { _ in
			XCTAssert(queue.isCurrent)
			futureExpectation.fulfill()
		}

		promise.reject(FutureError.some)

		waitForExpectations(timeout: 3)
	}

	func testPromiseWithTimeoutIsRejectedWithTimeoutNotOnMainQueueWhenDedicatedIsNotSpecified() {
		DispatchQueue.main.makeIdentifiable()
		let promiseExpectation = expectation(description: "promise")
		let futureExpectation = expectation(description: "future")
		let promise = FutureImpl<Int>()
		promise.observeWithTimeout(timeout: 1) { _ in
			XCTAssert(!DispatchQueue.main.isCurrent)
			promiseExpectation.fulfill()
		}
		promise.toFuture().observeWithTimeout(timeout: 1) { _ in
			XCTAssert(!DispatchQueue.main.isCurrent)
			futureExpectation.fulfill()
		}

		waitForExpectations(timeout: 3)
	}
}

private enum FutureError: Error {
	case some
}
