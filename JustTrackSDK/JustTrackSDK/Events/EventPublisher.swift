protocol EventPublisher: AnyObject {
	func publishEventBatch(batch: PublishingBatch) -> Future<Void>
	func register(attributionListener listener: @escaping (AttributionResponse) -> Void) -> Subscription
}
