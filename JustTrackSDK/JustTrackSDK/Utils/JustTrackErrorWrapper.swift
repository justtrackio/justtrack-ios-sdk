import Foundation

public class JustTrackErrorWrapper: NSObject, LocalizedError {
	public let error: Error

	public init(_ error: Error) {
		self.error = error
	}

	public override var description: String {
		error.justTrackGetErrorDescription()
	}

	public var errorDescription: String? {
		description
	}
}
