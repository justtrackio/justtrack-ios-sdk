import XCTest

@testable import JustTrackSDK

final class JustTrackSDKAdapterTests: XCTestCase {
	static let apiToken = TestCredentials.apiToken
	static let clientId = TestCredentials.clientId

	private var sdk: JustTrackSdk!
	private var mockAdapter: MockJustTrackSDKAdapter!

	override func setUp() {
		super.setUp()
		JustTrack.resetForTesting(clearStorage: true)
		mockAdapter = MockJustTrackSDKAdapter()
	}

	override func tearDown() {
		sdk?.shutdown()
		super.tearDown()
	}

	func testIntegrateWithAdapterWhenSdkIsRunning() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.build()

		let expectation = self.expectation(description: "Integration should complete")
		var integrationCompleted = false

		let future = sdk.integrate(with: mockAdapter)
		future.observe { _ in
			integrationCompleted = true
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1.0)

		XCTAssertTrue(integrationCompleted)
		XCTAssertEqual(mockAdapter.integrateCallCount, 1)
		XCTAssertTrue(mockAdapter.integrateCalledWith.first?.sdk === sdk)
		XCTAssertNotNil(mockAdapter.integrateCalledWith.first?.logger)
	}

	func testIntegrateWithAdapterWhenSdkIsNotRunning() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(manualStart: true)
			.build()

		let future = sdk.integrate(with: mockAdapter)

		XCTAssertEqual(mockAdapter.integrateCallCount, 0)

		sdk.start()

		let expectation = self.expectation(description: "Integration should complete after SDK starts")
		var integrationCompleted = false

		future.observe { _ in
			integrationCompleted = true
			expectation.fulfill()
		}

		waitForExpectations(timeout: 1.0)

		XCTAssertTrue(integrationCompleted)
		XCTAssertEqual(mockAdapter.integrateCallCount, 1)
		XCTAssertTrue(mockAdapter.integrateCalledWith.first?.sdk === sdk)
		XCTAssertNotNil(mockAdapter.integrateCalledWith.first?.logger)
	}

	func testIntegrateWithMultipleAdaptersBeforeSdkStarts() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.set(manualStart: true)
			.build()

		let mockAdapter2 = MockJustTrackSDKAdapter()
		let mockAdapter3 = MockJustTrackSDKAdapter()

		let future1 = sdk.integrate(with: mockAdapter)
		let future2 = sdk.integrate(with: mockAdapter2)
		let future3 = sdk.integrate(with: mockAdapter3)

		XCTAssertEqual(mockAdapter.integrateCallCount, 0)
		XCTAssertEqual(mockAdapter2.integrateCallCount, 0)
		XCTAssertEqual(mockAdapter3.integrateCallCount, 0)

		sdk.start()

		let expectation = self.expectation(description: "All integrations should complete")
		expectation.expectedFulfillmentCount = 3

		future1.observe { _ in expectation.fulfill() }
		future2.observe { _ in expectation.fulfill() }
		future3.observe { _ in expectation.fulfill() }

		waitForExpectations(timeout: 1.0)

		XCTAssertEqual(mockAdapter.integrateCallCount, 1)
		XCTAssertEqual(mockAdapter2.integrateCallCount, 1)
		XCTAssertEqual(mockAdapter3.integrateCallCount, 1)
	}

	func testIntegrateWithAdapterThatFails() throws {
		sdk = try JustTrackSdkBuilder(apiToken: Self.apiToken, clientId: Self.clientId)
			.build()
		sdk.start()

		let error = NSError(domain: "TestError", code: 42, userInfo: nil)
		mockAdapter.integrateStub = { _, _ in
			return FutureImpl<Void>().reject(error)
		}

		let expectation = self.expectation(description: "Integration should fail")
		var receivedError: Error?

		let future = sdk.integrate(with: mockAdapter)
		future.observe { result in
			switch result {
			case let .failure(error):
				receivedError = error
				expectation.fulfill()
			case .success:
				break
			}
		}

		waitForExpectations(timeout: 1.0)

		XCTAssertNotNil(receivedError)
		XCTAssertEqual((receivedError as NSError?)?.code, 42)
		XCTAssertEqual(mockAdapter.integrateCallCount, 1)
	}
}
