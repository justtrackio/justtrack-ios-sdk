enum DefaultSqliteDriverError: Error {
	case databaseOpening(String)
	case tableCreation(String)
	case insertion(String)
	case removal(String)
	case fetching(String)
}

extension DefaultSqliteDriverError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case let .databaseOpening(message):
			return "<DefaultSqliteDriver> Database opening error: \(message)"
		case let .tableCreation(message):
			return "<DefaultSqliteDriver> Table creation error: \(message)"
		case let .insertion(message):
			return "<DefaultSqliteDriver> Insertion error: \(message)"
		case let .removal(message):
			return "<DefaultSqliteDriver> Removal error: \(message)"
		case let .fetching(message):
			return "<DefaultSqliteDriver> Fetching error: \(message)"
		}
	}
}
