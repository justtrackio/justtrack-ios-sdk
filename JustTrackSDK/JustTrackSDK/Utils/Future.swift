import Foundation

/// The result of an operation that could timeout.
public enum TimeoutResult<Success, Failure> where Failure: Error {
	/// A successful outcome with an associated value of type `Success`.
	case success(Success)
	/// A failure outcome with an associated error of type `Failure`.
	case failure(Failure)
	/// Represents an operation that did not complete within the allotted time.
	case timeout
}

/// A future value of type `Value`.
public struct Future<Value> {
	/// A result that can either succeed with `Value` or fail with `Error`.
	public typealias Result = Swift.Result<Value, Error>
	/// A callback type for observing the result.
	public typealias ObserveCallback = (Result) -> Void
	/// A callback type for observing the result with a timeout consideration.
	public typealias ObserveCallbackWithTimeout = (TimeoutResult<Value, Error>) -> Void

	/// A boolean property indicating whether the future has been fulfilled.
	public var isFulfilled: Bool { isFulfilledProvider() }

	private let observeHandler: (DispatchQueue?, @escaping ObserveCallback) -> Void
	private let observeWithTimeoutHandler: (DispatchQueue?, TimeInterval, @escaping ObserveCallbackWithTimeout) -> Void
	private let isFulfilledProvider: () -> Bool

	fileprivate init(
		handler: @escaping (DispatchQueue?, @escaping ObserveCallback) -> Void,
		handlerWithTimeout: @escaping (DispatchQueue?, TimeInterval, @escaping ObserveCallbackWithTimeout) -> Void,
		isFulfilledProvider: @escaping () -> Bool
	) {
		self.observeHandler = handler
		self.observeWithTimeoutHandler = handlerWithTimeout
		self.isFulfilledProvider = isFulfilledProvider
	}

	/// Observes the result of the future.
	/// - Parameters:
	///   - queue: The dispatch queue on which the handler is executed. If `nil`, an arbitrary queue is used.
	///   - handler: The closure to call with the future's result.
	public func observe(
		on queue: DispatchQueue? = nil,
		using handler: @escaping ObserveCallback
	) {
		observeHandler(queue, handler)
	}

	/// Observes the result of the future with a timeout.
	/// - Parameters:
	///   - queue: The dispatch queue on which the callback is executed. If `nil`, an arbitrary queue is used.
	///   - timeout: The time interval after which the future should timeout.
	///   - handler: The closure to call with the future's result or a timeout.
	public func observeWithTimeout(
		on queue: DispatchQueue? = nil,
		timeout: TimeInterval,
		using handler: @escaping ObserveCallbackWithTimeout
	) {
		observeWithTimeoutHandler(queue, timeout, handler)
	}

	/// Asynchronously waits for the future to be resolved and returns the value.
	/// - Throws: An error if the future is resolved with a failure.
	/// - Returns: The success value of the future.
	@available(iOS 13.0, *)
	public func async() async throws -> Value {
		return try await withCheckedThrowingContinuation { continuation in
			observe { result in
				switch result {
				case .success(let value):
					continuation.resume(returning: value)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
}

protocol ToFuture {
	associatedtype Value
	func toFuture() -> Future<Value>
}

protocol Promise {
	associatedtype Value
	func resolve(_ value: Value) -> Future<Value>
	func reject(_ error: Error) -> Future<Value>
}

/// An implementation of a future for managing and observing its value.
public class FutureImpl<Value>: ToFuture, Promise {
	typealias Value = Value
	typealias Result = Swift.Result<Value, Error>

	private struct Callback {
		let queue: DispatchQueue?
		let handler: (Result) -> Void
	}

	/// A boolean property indicating whether the promise (and hence the future) has been fulfilled.
	public var isFulfilled: Bool {
		mutex.lock()
		defer { mutex.unlock() }
		return result != nil
	}

	private var result: Result?
	private var callbacks = [Callback]()
	private let mutex = NSRecursiveLock()

	/// Initializes a new instance of `FutureImpl` with an optional initial value.
	/// - Parameter value: The initial value of the future. If provided, the future is considered fulfilled immediately.
	public init(_ value: Value? = nil) {
		// If the value was already known at the time the promise
		// was constructed, we can report it directly:
		result = value.map(Result.success)
	}

	/// Resolves the promise with a success value.
	/// - Parameter value: The value to resolve the promise with.
	/// - Returns: The future associated with the promise.
	@discardableResult
	public func resolve(_ value: Value) -> Future<Value> {
		return fulfill(.success(value))
	}

	/// Rejects the promise with an error.
	/// - Parameter error: The error to reject the promise with.
	/// - Returns: The future associated with the promise.
	@discardableResult
	public func reject(_ error: Error) -> Future<Value> {
		return fulfill(.failure(error))
	}

	/// Converts this instance into a `Future`.
	/// - Returns: A `Future` representing the eventual result of the promise.
	public func toFuture() -> Future<Value> {
		return Future(
			handler: self.observe(on:using:),
			handlerWithTimeout: self.observeWithTimeout(on:timeout:using:),
			isFulfilledProvider: self.provideIsFulfilled
		)
	}

	func observe(
		on queue: DispatchQueue? = nil,
		using handler: @escaping (Result) -> Void
	) {
		mutex.lock()
		// If a result has already been set, call the callback directly:
		if let result {
			mutex.unlock()
			runHandler(on: queue, result: result, handler: handler)
			return
		}

		defer { mutex.unlock() }

		callbacks.append(
			Callback(queue: queue, handler: handler)
		)
	}

	func observeWithTimeout(
		on queue: DispatchQueue? = nil,
		timeout: TimeInterval,
		using handler: @escaping (TimeoutResult<Value, Error>) -> Void
	) {
		mutex.lock()
		// If a result has already been set, call the callback directly:
		if let result {
			mutex.unlock()

			switch result {
			case let .failure(error):
				runHandler(on: queue, result: .failure(error), handler: handler)
			case let .success(value):
				runHandler(on: queue, result: .success(value), handler: handler)
			}
		}

		mutex.unlock()

		let mu = NSRecursiveLock()

		let timer = DispatchSource.makeTimerSource(queue: queue)
		timer.schedule(deadline: .now() + .milliseconds(Int(timeout * 1_000)), repeating: .never)
		timer.setEventHandler {
			mu.lock()
			if timer.isCancelled {
				mu.unlock()
				return
			}

			timer.cancel()
			mu.unlock()

			self.runHandler(on: queue, result: .timeout, handler: handler)
		}

		observe(on: queue) { result in
			mu.lock()
			if timer.isCancelled {
				mu.unlock()
				return
			}

			timer.cancel()
			mu.unlock()

			switch result {
			case let .failure(error):
				self.runHandler(on: queue, result: .failure(error), handler: handler)
			case let .success(value):
				self.runHandler(on: queue, result: .success(value), handler: handler)
			}
		}

		timer.activate()
	}

	@discardableResult
	func fulfill(_ result: Result) -> Future<Value> {
		let toCall = doFulfill(result)

		// will always call with the correct result. if we are called twice,
		// there are no new callbacks because they all already find a result available
		toCall.forEach { callback in
			runHandler(on: callback.queue, result: result, handler: callback.handler)
		}

		return self.toFuture()
	}

	func fulfillWith(_ callback: () throws -> Value) -> FutureImpl<Value> {
		var result: Value?
		do {
			result = try callback()
		} catch {
			_ = self.reject(error)
			return self
		}
		if let result {
			_ = self.resolve(result)
			return self
		}
		return self
	}

	func runHandler<T>(
		on queue: DispatchQueue?,
		result: T,
		handler: @escaping (T) -> Void
	) {
		if let queue {
			queue.async {
				handler(result)
			}
		} else {
			handler(result)
		}
	}

	private func doFulfill(_ result: Result) -> [Callback] {
		var toCall = [Callback]()

		mutex.lock()
		defer { mutex.unlock() }

		// if we set a value twice, just ignore it
		if self.result == nil {
			self.result = result
		}

		toCall = callbacks
		callbacks = []

		return toCall
	}

	private func provideIsFulfilled() -> Bool {
		return isFulfilled
	}
}

struct TransformingFuture<Source, Target>: ToFuture {
	typealias Value = Target
	private let mapped: Future<Source>
	private let mapper: (Source) -> Target

	init(_ mapped: Future<Source>, _ mapper: @escaping (Source) -> Target) {
		self.mapped = mapped
		self.mapper = mapper
	}

	func toFuture() -> Future<Target> {
		return Future(
			handler: self.observe(on:using:),
			handlerWithTimeout: self.observeWithTimeout(on:timeout:using:),
			isFulfilledProvider: self.provideIsFulfilled
		)
	}

	func observe(
		on queue: DispatchQueue? = nil,
		using handler: @escaping (Result<Target, Error>) -> Void
	) {
		mapped.observe {
			switch $0 {
			case let .failure(err):
				handler(.failure(err))
			case let .success(source):
				handler(.success(self.mapper(source)))
			}
		}
	}

	func observeWithTimeout(
		on queue: DispatchQueue? = nil,
		timeout: TimeInterval,
		using callback: @escaping (TimeoutResult<Target, Error>) -> Void
	) {
		mapped.observeWithTimeout(on: queue, timeout: timeout) {
			switch $0 {
			case .failure(let err):
				callback(.failure(err))
			case .timeout:
				callback(.timeout)
			case .success(let source):
				callback(.success(self.mapper(source)))
			}
		}
	}

	private func provideIsFulfilled() -> Bool {
		return mapped.isFulfilled
	}
}

private let requestRetriesMetric = Metric(metric: "RequestRetries")

class RetryingFuture<Value>: FutureImpl<Value> {
	private var retries: Int
	private let getNextRetry: (Int) -> TimeInterval?
	private var getTry: (() -> Future<Value>)?
	private let errorClassifier: ErrorClassifier
	private let logger: Logger
	private let requestName: String?

	convenience init(
		retries maxRetries: Int,
		logger: Logger,
		requestName: String?,
		classifier: ErrorClassifier,
		for getTry: @escaping () -> Future<Value>
	) {
		self.init(
			logger: logger,
			requestName: requestName,
			getNextRetry: { retries in
				if retries >= maxRetries {
					return nil
				}

				return min(15.0, 0.25 * pow(2.0, Double(retries)) * Double.random(in: 0.5...1.5))
			},
			classifier: classifier,
			for: getTry
		)
	}

	convenience init(
		retryDelaySeconds: [TimeInterval],
		logger: Logger,
		requestName: String?,
		classifier: ErrorClassifier,
		for getTry: @escaping () -> Future<Value>
	) {
		self.init(
			logger: logger,
			requestName: requestName,
			getNextRetry: { retries in
				if retries >= retryDelaySeconds.count {
					return nil
				}

				return retryDelaySeconds[retries]
			},
			classifier: classifier,
			for: getTry
		)
	}

	private init(
		logger: Logger,
		requestName: String?,
		getNextRetry: @escaping (Int) -> TimeInterval?,
		classifier: ErrorClassifier,
		for getTry: @escaping () -> Future<Value>
	) {
		self.retries = 0
		self.getNextRetry = getNextRetry
		self.errorClassifier = classifier
		self.getTry = getTry
		self.logger = logger
		self.requestName = requestName
		super.init()

		self.performTry(getTry: getTry)
	}

	private func observeChild(connectionType: ConnectionType, response: Future<Value>.Result) {
		switch response {
		case .failure(let error):
			guard let waitTime = getNextRetry(retries) else {
				_ = fulfill(response)
				return
			}

			if let requestName {
				let dimensions = LoggerFieldsImpl().with("Request", requestName).with("Network", connectionType.stringValue)
				logger.publishMetric(requestRetriesMetric, 1, dimensions)
			}

			retries += 1

			let waitFor: TimeInterval
			switch RetryingFuture.classifyError(error: error, errorClassifier: errorClassifier) {
			case .unrecoverable:
				_ = fulfill(response)
				return
			case .retryDefault:
				waitFor = waitTime
			case .recoverable(let waitTime):
				waitFor = waitTime
			}

			// we have to switch to the main thread to schedule a timer, otherwise
			// it won't have a run loop associated with it and will never fire
			DispatchQueue.main.async {
				Timer.scheduledTimer(withTimeInterval: waitFor, repeats: false) { [self] _ in
					if let getTry = self.getTry {
						self.performTry(getTry: getTry)
					} else {
						_ = self.reject(error)
					}
				}
			}
		case .success(let data):
			self.getTry = nil
			_ = resolve(data)
		}
	}

	private func performTry(getTry: () -> Future<Value>) {
		let connectionType = getNetworkType()

		getTry().observe(using: { response in
			self.observeChild(connectionType: connectionType, response: response)
		})
	}

	static func classifyError(error: Error, errorClassifier: ErrorClassifier) -> ErrorClassification {
		if let justTrackError = error as? JustTrackErrorWrapper {
			if let networkError = justTrackError.error as? NetworkError {
				return errorClassifier.classify(error: networkError) ?? .retryDefault
			}
		}

		return .retryDefault
	}
}

struct RetryConfig {
	static let defaultConfig = RetryConfig(attributionRequestRetries: 5, fetchClaimRetries: 5, publishEventsRetries: 5)
	let attributionRequestRetries: Int
	let fetchClaimRetries: Int
	let publishEventsRetries: Int
}
