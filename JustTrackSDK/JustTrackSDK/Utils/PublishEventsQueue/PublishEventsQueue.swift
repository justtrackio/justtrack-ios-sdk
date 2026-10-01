import Foundation
import UIKit

let publishEventsGlobalQueue = DispatchQueue(label: "io.justtrack.JustTrackSDK.PublishEventsQueue.queue", qos: .userInteractive)

final class PublishEventsQueue {
	private static let maxBatchSize: Int = 100
	private static let waitTime: TimeInterval = 5

	private var attributionSubscription: Subscription?
	private var done: Bool
	private var currentBatch: Batch?
	private weak var publisher: EventPublisher?
	private var reconnectSubscription: Subscription?
	private var retryQueue: [PublishingEvent]
	private var workQueue: [PublishingEvent]

	private let eventStore: EventStoring
	private let logger: HttpLogger
	private let queue: DispatchQueue
	private let sequenceNumberProvider: SequenceNumberProvider
	private let sqliteDriver: SqliteDriver
	private let sdkVersionProvider: () -> any Version

	init(
		connectivityManager: ConnectivityManager?,
		eventStore: EventStoring = EventStore(),
		logger: HttpLogger,
		publisher: EventPublisher,
		queue: DispatchQueue = publishEventsGlobalQueue,
		sequenceNumberProvider: SequenceNumberProvider,
		sqliteDriver: SqliteDriver,
		sdkVersionProvider: @escaping () -> any Version = currentSdkVersion
	) {
		self.done = false
		self.currentBatch = nil
		self.publisher = publisher
		self.retryQueue = []
		self.workQueue = []

		self.eventStore = eventStore
		self.logger = logger
		self.queue = queue
		self.sequenceNumberProvider = sequenceNumberProvider
		self.sqliteDriver = sqliteDriver
		self.sdkVersionProvider = sdkVersionProvider

		self.reconnectSubscription = connectivityManager?.registerOnReconnect(self.onReachable)
		self.attributionSubscription = publisher.register { _ in self.onReachable() }

		queue.async {
			self.restorePreservedEvents()
		}
	}

	func moveToBackground() {
		let container = UIBackgroundTaskIdentifierContainer()
		container.identifier = UIApplication.shared.beginBackgroundTask {
			UIApplication.shared.endBackgroundTask(container.identifier)
		}

		// We schedule this call to execute all the pending tasks in the queue before the background task is ended.
		queue.async {
			UIApplication.shared.endBackgroundTask(container.identifier)
		}
	}

	func onReachable() {
		queue.async { [self] in
			// all events we want to retry are now new work, enqueue them
			workQueue.append(contentsOf: retryQueue)
			retryQueue = []

			// and then schedule to be called again (easier with the locks that way)
			handle()
		}
	}

	func publishEvent(
		event: PublishableUserEvent
	) -> Future<Void> {
		let promise = FutureImpl<Void>()

		queue.async { [self] in
			let id = eventStore.getNextId()
			let sequenceNumber = sequenceNumberProvider.provideNext()

			let publishingEvent = PublishingEvent(event: StorableEvent(id: id, event: event, sequenceNumber: sequenceNumber, sdkVersion: sdkVersionProvider()))

			logger.debug(
				"PublishEventsQueue: Received event seqNo \(publishingEvent.sequenceNumber()), \(publishingEvent.event.event) at \(publishingEvent.happenedAt())"
			)

			eventStore.storeEvent(event: publishingEvent.event)
			do {
				try sqliteDriver.storeEvent(publishingEvent.event)
			} catch {
				logDatabaseError("Failed to store event in database", error: error)
			}

			publishingEvent.promise.observe(on: .main) { [weak logger] result in
				switch result {
				case let .failure(error):
					let message =
						"PublishEventsQueue: Failed to publish event seqNo \(publishingEvent.sequenceNumber()), "
						+ "\(publishingEvent.event.event) at \(publishingEvent.happenedAt()) error: \(error.localizedDescription)"
					#if DEBUG
						logger?.debug(message)
					#else
						logger?.getFallback().debug(message)
					#endif

				case .success:
					let message =
						"PublishEventsQueue: Successfully published event seqNo \(publishingEvent.sequenceNumber()), \(publishingEvent.event.event) at \(publishingEvent.happenedAt()) in batch"
					#if DEBUG
						logger?.debug(message)
					#else
						logger?.getFallback().debug(message)
					#endif
				}
				promise.fulfill(result)
			}

			workQueue.append(publishingEvent)
			handle()
		}

		return promise.toFuture()
	}

	func shutdown() {
		queue.async { [self] in
			done = true
			// we are no longer interested in any updates, so stop this
			reconnectSubscription?.unsubscribe()
			reconnectSubscription = nil
			attributionSubscription?.unsubscribe()
			attributionSubscription = nil
		}
	}

	private func handle() {
		if self.done {
			return
		}

		while let nextEvent = workQueue.popLast() {
			currentBatch = currentBatch ?? Batch()
			if let batch = currentBatch {
				batch.batch.append(nextEvent)

				if batch.batch.count >= Self.maxBatchSize
					|| (nextEvent.event.event.name == JtSessionTrackingEvent.name && nextEvent.event.event.dimensions[Dimension.jtAction.rawValue] == "end")
				{
					publish(events: batch.batch)
					currentBatch = nil
				}
			}
		}

		if let batch = currentBatch {
			// we have a batch to publish, start the countdown
			queue.asyncAfter(
				deadline: .now() + Self.waitTime,
				execute: {
					if let newBatch = self.currentBatch {
						if newBatch.id == batch.id {
							self.publish(events: newBatch.batch)
							self.currentBatch = nil
						}
					}
				}
			)
		}
	}

	private func logDatabaseError(
		_ message: String,
		error: Error? = nil,
		fields: LoggerFields...
	) {
		if let error {
			logger.error("<PublishEventsQueue> \(message)", error, fields)
		} else {
			logger.error("<PublishEventsQueue> \(message)", fields)
		}
	}

	private func publish(
		events: [PublishingEvent]
	) {
		guard !events.isEmpty else { return }

		var eventsBySdkVersion = [PublishingSdkVersionKey: [PublishingEvent]]()

		for event in events {
			let sdkVersionKey = PublishingSdkVersionKey(version: event.event.sdkVersion)
			var versionedEvents = (eventsBySdkVersion[sdkVersionKey] ?? [])
			versionedEvents.append(event)
			eventsBySdkVersion[sdkVersionKey] = versionedEvents
		}

		for (sdkVersionKey, versionedEvents) in eventsBySdkVersion.sorted(by: { $0.key.version.name < $1.key.version.name }) {
			let batch = PublishingBatch(events: versionedEvents, sdkVersion: sdkVersionKey.version)
			publisher?.publishEventBatch(batch: batch).observe(on: queue) { [self] result in
				switch result {
				case .failure:
					for event in batch.events {
						retryQueue.append(event)
					}
				case .success:
					let eventIds = batch.events.map(\.event.id)
					do {
						try sqliteDriver.removeEvents(eventIds: eventIds)
					} catch {
						logDatabaseError("Failed to remove event batch from database", error: error)
					}
					for event in batch.events {
						eventStore.removeEvent(event: event.event)
						_ = event.promise.resolve(Void())
					}
				}
			}
		}
	}

	private func restorePreservedEvents() {
		let storeEvents = eventStore.readEvents()
		let dbEvents = {
			do {
				return try sqliteDriver.fetchEvents()
			} catch {
				logDatabaseError("Failed to fetch events from database", error: error)
				return []
			}
		}()

		if dbEvents != storeEvents {
			logDatabaseError("Events from database do not match events from store")
		}

		workQueue.append(contentsOf: storeEvents.map(PublishingEvent.init))
		if workQueue.count > 0 {
			handle()
		}
	}
}

// needs to be a class - if you change this to a struct, we will append new events to a
// COPY of the current batch, causing us to never fill the batch!
private class Batch {
	let id: StringID
	var batch: [PublishingEvent]

	init() {
		id = StringID()
		batch = []
	}
}
