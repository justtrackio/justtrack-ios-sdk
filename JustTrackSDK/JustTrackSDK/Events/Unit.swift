/// An enum describing how to interpret the value of a UserEvent.
public enum Unit: String, CaseIterable, CustomStringConvertible, Codable {
	/// We want to count how many times something happened in total.
	case count
	/// We want to measure how long something takes with millisecond precision.
	case milliseconds
	/// We want to measure how long something takes with second precision.
	case seconds

	public var description: String {
		rawValue
	}
}

/// A time-based unit grouping the milliseconds and seconds Units.
public enum TimeUnitGroup: Int {
	/// See Unit.milliseconds
	case milliseconds
	/// See Unit.seconds
	case seconds

	var unitValue: Unit {
		switch self {
		case .milliseconds:
			return .milliseconds
		case .seconds:
			return .seconds
		}
	}
}
