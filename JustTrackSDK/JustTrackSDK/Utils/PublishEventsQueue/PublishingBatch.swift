import Foundation

struct PublishingBatch {
	let events: [PublishingEvent]
	let sdkVersion: any Version
}
