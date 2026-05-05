@testable import JustTrackSDK

final class MockEventPublisher: EventPublisher {
	enum Call {
		case publishEventBatch([PublishingBatchItem])
		case registerAttributionListener
	}

	var calls = [Call]()

	var publishEventBatchPromise = FutureImpl<Void>()
	var registerAttributionListenerSubscriptions = SubscriptionManager<AttributionResponse>()

	func reset() {
		calls = []
	}

	func publishEventBatch(batch: PublishingBatch) -> Future<Void> {
		let publishingBatch = batch.events.map { event in
			PublishingBatchItem(
				eventId: event.eventId(),
				baseEvent: event.baseEvent(),
				happenedAt: event.happenedAt(),
				sequenceNumber: event.sequenceNumber(),
				sdkVersion: event.event.sdkVersion
			)
		}
		calls.append(.publishEventBatch(publishingBatch))
		return publishEventBatchPromise.toFuture()
	}

	func register(attributionListener listener: @escaping (AttributionResponse) -> Void) -> Subscription {
		calls.append(.registerAttributionListener)
		return registerAttributionListenerSubscriptions.subscribe(listener: listener)
	}
}

struct PublishingBatchItem {
	let eventId: StringID
	let baseEvent: PublishableUserEvent
	let happenedAt: Date
	let sequenceNumber: Int
	let sdkVersion: any Version
}
