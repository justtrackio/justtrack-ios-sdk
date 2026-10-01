public enum PlatformType: String, CustomStringConvertible {
	case native
	case unity
	case reactNative
	case flutter
	case godot

	public var description: String {
		switch self {
		case .native:
			return "iOS"
		case .unity:
			return "Unity; iOS"
		case .reactNative:
			return "ReactNative; iOS"
		case .flutter:
			return "Flutter; iOS"
		case .godot:
			return "Godot; iOS"
		}
	}

	var wrapper: String? {
		switch self {
		case .native:
			return nil
		case .unity:
			return "unity"
		case .reactNative:
			return "react-native"
		case .flutter:
			return "flutter"
		case .godot:
			return "godot"
		}
	}
}
