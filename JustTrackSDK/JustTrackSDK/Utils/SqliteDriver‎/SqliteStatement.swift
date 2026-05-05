import SQLite3

enum ColumnData {
	case date(Date)
	case double(Double)
	case integer(Int)
	case json([String: String])
	case string(String)
}

extension Date {
	func columnData() -> ColumnData {
		return .date(self)
	}
}

extension Double {
	func columnData() -> ColumnData {
		return .double(self)
	}
}

extension Int {
	func columnData() -> ColumnData {
		return .integer(self)
	}
}

extension String {
	func columnData() -> ColumnData {
		return .string(self)
	}
}

extension [String: String] {
	func columnData() -> ColumnData {
		return .json(self)
	}
}

extension Version {
	func columnData() -> ColumnData {
		let json = [
			"major": String(major),
			"minor": String(minor),
			"patch": String(patch),
			"name": name,
		]
		return .json(json)
	}
}

struct Row {
	private var nextIndex: Int32
	private let statement: OpaquePointer?

	fileprivate init(
		statement: OpaquePointer?
	) {
		self.nextIndex = 0
		self.statement = statement
	}

	mutating func integer() -> Int {
		let result = Int(sqlite3_column_int64(statement, nextIndex))
		nextIndex += 1

		return result
	}

	mutating func string() -> String {
		let result = String(cString: sqlite3_column_text(statement, nextIndex))
		nextIndex += 1

		return result
	}

	mutating func json() -> [String: String] {
		let jsonString = string()
		if let data = jsonString.data(using: .utf8),
			let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
		{
			return dict
		}

		return [:]
	}

	mutating func double() -> Double {
		let result = sqlite3_column_double(statement, nextIndex)
		nextIndex += 1

		return result
	}

	mutating func date() -> Date {
		return Date(timeIntervalSince1970: double())
	}

	mutating func opt<T>(
		provider: (inout Row) -> T
	) -> T? {
		if sqlite3_column_type(statement, nextIndex) == SQLITE_NULL {
			nextIndex += 1

			return nil
		}

		return provider(&self)
	}
}

struct Statement {
	private let db: OpaquePointer?
	private let errorProvider: (String) -> Error

	private var statement: OpaquePointer?

	init(
		db: OpaquePointer?,
		command: String,
		errorProvider: @escaping (String) -> Error
	) throws {
		self.db = db
		self.errorProvider = errorProvider
		let preparationResult = sqlite3_prepare_v2(db, command, -1, &statement, nil)
		if preparationResult != SQLITE_OK {
			let errMsg = String(cString: sqlite3_errmsg(db))
			throw errorProvider(errMsg)
		}
	}

	func execute() throws {
		let result = sqlite3_step(statement)
		guard result == SQLITE_DONE else {
			let errMsg = String(cString: sqlite3_errmsg(db))
			throw errorProvider(errMsg)
		}
	}

	func insert(
		columns: [ColumnData?]
	) throws -> Int64 {
		for i in 0..<columns.count {
			try bind(column: columns[i], index: Int32(i) + 1)
		}

		try execute()

		return sqlite3_last_insert_rowid(db)
	}

	func fetch(
		onRow: (inout Row) -> Void
	) throws {
		while true {
			switch sqlite3_step(statement) {
			case SQLITE_ROW:
				var row = Row(statement: statement)
				onRow(&row)
			case SQLITE_DONE:
				return
			default:
				let errMsg = String(cString: sqlite3_errmsg(db))
				throw errorProvider(errMsg)
			}
		}
	}

	private func bind(
		column: ColumnData?,
		index: Int32
	) throws {
		switch column {
		case let .date(date):
			bind(date: date, index: index)
		case let .double(double):
			bind(double: double, index: index)
		case let .integer(integer):
			bind(integer: integer, index: index)
		case let .json(json):
			try bind(json: json, index: index)
		case let .string(string):
			bind(string: string, index: index)
		case .none:
			bindNull(index: index)
		}
	}

	private func bind(
		date: Date,
		index: Int32
	) {
		bind(double: date.timeIntervalSince1970, index: index)
	}

	private func bind(
		double: Double,
		index: Int32
	) {
		sqlite3_bind_double(statement, index, double)
	}

	private func bind(
		integer: Int,
		index: Int32
	) {
		sqlite3_bind_int64(statement, index, Int64(integer))
	}

	private func bind(
		json: Any,
		index: Int32
	) throws {
		let data = try JSONSerialization.data(withJSONObject: json, options: [])
		if let jsonString = String(data: data, encoding: .utf8) {
			bind(string: jsonString, index: index)
		} else {
			bindNull(index: index)
		}
	}

	private func bind(
		string: String,
		index: Int32
	) {
		sqlite3_bind_text(statement, index, (string as NSString).utf8String, -1, nil)
	}

	private func bindNull(
		index: Int32
	) {
		sqlite3_bind_null(statement, index)
	}

	mutating func finalize() throws {
		if statement == nil {
			return
		}
		let finalizationResult = sqlite3_finalize(statement)
		if finalizationResult != SQLITE_OK {
			let errMsg = String(cString: sqlite3_errmsg(db))
			throw errorProvider(errMsg)
		}
		statement = nil
	}
}
