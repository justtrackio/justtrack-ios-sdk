# justtrack SDK

The [justtrack SDK](https://justtrack.io/) is a marketing SDK with full MMP (Mobile Measurement Partner) capabilities for your iOS application. It provides attribution, event tracking, ad revenue forwarding, in-app purchase tracking, retargeting, remote config, and more.

You can find the complete documentation at <https://docs.justtrack.io/sdk/overview/>.

## Requirements

| Property              | Version |
|-----------------------|---------|
| iOS Deployment Target | 12.0    |
| Xcode                 | 16.0+   |
| Swift                 | 5.7+    |

## Installation

### CocoaPods

Add the following line to your `Podfile`:

```ruby
pod 'JustTrackSDK', '7.1.0'
```

Then run:

```bash
pod install
```

### Swift Package Manager

Add the justtrack SDK package to your Xcode project via **File > Add Package Dependencies** using the following URL:

```
https://github.com/justtrackio/justtrack-sdk-spm
```

### Carthage

Add the following to your `Cartfile`:

```
binary "https://sdk.justtrack.io/carthage/JustTrackSDK.json" ~> 7.1.0
```

Then run:

```bash
carthage update
```

## Getting Started

### Instantiate the SDK

In your app, create an instance of the SDK using `JustTrackSdkBuilder`:

```swift
import JustTrackSDK

do {
    let sdk = try JustTrackSdkBuilder(apiToken: "YOUR_API_TOKEN").build()
} catch {
    // apiToken has invalid format...
}
```

You should call `shutdown()` on the SDK when your app terminates. This will unregister all listeners and tear down the session tracking. You have to create a new instance of the SDK before you can use it again.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on the project structure, prerequisites, quality checks, and contribution workflow.

## Support

If you have any problems or issues with the SDK, feel free to reach out directly via [support@justtrack.io](mailto:support@justtrack.io).

## License

This project is licensed under the MIT License. See the [LICENSE](/LICENSE) file for details.
