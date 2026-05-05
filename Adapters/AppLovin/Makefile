.PHONY: all clean generate

all: generate

generate:
	@echo "Generating Xcode project for JustTrackSDKAppLovinAdapter..."
	@xcodegen generate

clean:
	@echo "Cleaning generated files..."
	@rm -rf JustTrackSDKAppLovinAdapter.xcodeproj
	@rm -rf JustTrackSDKAppLovinAdapter.xcworkspace
	@find . -name "*.xcworkspace" -type d -exec rm -rf {} +
	@find . -name "*.xcodeproj" -type d -exec rm -rf {} +