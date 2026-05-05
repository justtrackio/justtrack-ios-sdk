struct DTOAnonymizeRequest: Encodable, Equatable, DTO {
	let installInstanceId: String
	let deviceId: String?
	let idfv: String?

	init(
		installInstanceId: StringID,
		deviceId: StringID?,
		idfv: StringID?
	) {
		self.installInstanceId = installInstanceId.value
		self.deviceId = deviceId?.value
		self.idfv = idfv?.value
	}

	func json() throws -> Data {
		return try JSONEncoder().encode(self)
	}
}
