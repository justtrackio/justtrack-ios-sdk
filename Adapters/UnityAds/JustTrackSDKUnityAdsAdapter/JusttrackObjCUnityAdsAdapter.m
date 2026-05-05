#import "JusttrackObjCUnityAdsAdapter.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (*LoadCallbackWithOptions)(Class, SEL, UIViewController*, NSString*, id, id);
typedef id (*GetBannerViewWithBannerAdId)(id bannerViewManager, SEL _selector, NSString* bannerAdId);
typedef void (*TriggerBannerDidLoad)(id bannerViewManager, SEL _selector, NSString* bannerAdId);
typedef void (*SendAdLoaded)(id, SEL, NSString*, NSString*);
typedef NSString* (*GetVersion)(Class, SEL);

static LoadCallbackWithOptions __nullable loadCallbackWithOptions = NULL;
static GetBannerViewWithBannerAdId __nullable getBannerViewWithBannerAdId = NULL;
static TriggerBannerDidLoad __nullable triggerBannerDidLoad = NULL;
static SendAdLoaded __nullable sendAdLoaded = NULL;
static GetVersion __nullable getVersion = NULL;
static Class __nullable UADSBannerLoadModuleClass = NULL;

static void (^__nullable forwardBlockStatic)(NSString*, NSString*, NSNumber* __nullable) = nil;
static void (^__nullable reportingBlockStatic)(NSString*) = nil;
static NSMutableDictionary *bannerDelegates = nil;

@interface JTBannerDelegate : NSObject
@property (nonatomic, weak) id originalDelegate;
- (id) initWithOriginalDelegate:(id)delegate;
@end

@implementation JTBannerDelegate

- (id) initWithOriginalDelegate:(id)delegate {
	self = [super init];
	if (self != NULL) {
		self.originalDelegate = delegate;
	}
	return self;
}

- (void)bannerViewDidLoad:(id)bannerView {
	SEL placementIdSelector = NSSelectorFromString(@"placementId");
	if ([bannerView respondsToSelector:placementIdSelector]) {
		NSString *placementId = ((NSString* (*)(id, SEL))objc_msgSend)(bannerView, placementIdSelector);
		if (forwardBlockStatic && placementId) {
			forwardBlockStatic(@"banner", placementId, nil);
		}
	}
	
	if (self.originalDelegate && [self.originalDelegate respondsToSelector:@selector(bannerViewDidLoad:)]) {
		[self.originalDelegate bannerViewDidLoad:bannerView];
	}
}

- (void)bannerViewDidShow:(id)bannerView {
	if (self.originalDelegate && [self.originalDelegate respondsToSelector:@selector(bannerViewDidShow:)]) {
		[self.originalDelegate bannerViewDidShow:bannerView];
	}
}

- (void)bannerViewDidClick:(id)bannerView {
	if (self.originalDelegate && [self.originalDelegate respondsToSelector:@selector(bannerViewDidClick:)]) {
		[self.originalDelegate bannerViewDidClick:bannerView];
	}
}

- (void)bannerViewDidError:(id)bannerView error:(id)error {
	if (self.originalDelegate && [self.originalDelegate respondsToSelector:@selector(bannerViewDidError:error:)]) {
		[self.originalDelegate bannerViewDidError:bannerView error:error];
	}
}

- (void)bannerViewDidLeaveApplication:(id)bannerView {
	if (self.originalDelegate && [self.originalDelegate respondsToSelector:@selector(bannerViewDidLeaveApplication:)]) {
		[self.originalDelegate bannerViewDidLeaveApplication:bannerView];
	}
}

@end

@interface JTReportingShowDelegate : NSObject
@end

@implementation JTReportingShowDelegate

- (void)unityAdsShowClick:(nonnull NSString *)placementId {
}

- (void)unityAdsShowComplete:(nonnull NSString *)placementId withFinishState:(NSInteger)state {
	bool isCompleted = state == 0;
	if (forwardBlockStatic) {
		forwardBlockStatic(@"impression", placementId, @(isCompleted));
	}
}

- (void)unityAdsShowFailed:(nonnull NSString *)placementId withError:(NSInteger)error withMessage:(nonnull NSString *)message {
}

- (void)unityAdsShowStart:(nonnull NSString *)placementId {
}

@end

@interface JTWrappingShowDelegate : NSObject
@property (nonatomic, strong) id wrapped;
- (id) init: (id)wrapped;
@end

@implementation JTWrappingShowDelegate

- (id) init: (id)wrapped {
	self = [super init];

	if (self != NULL) {
		self.wrapped = wrapped;
	}

	return self;
}

- (void)unityAdsShowClick:(nonnull NSString *)placementId {
	SEL selector = NSSelectorFromString(@"unityAdsShowClick:");
	if ([self.wrapped respondsToSelector:selector]) {
		((void (*)(id, SEL, NSString*))objc_msgSend)(self.wrapped, selector, placementId);
	}
}

- (void)unityAdsShowComplete:(nonnull NSString *)placementId withFinishState:(NSInteger)state {
	bool isCompleted = state == 0;
	if (forwardBlockStatic) {
		forwardBlockStatic(@"impression", placementId, @(isCompleted));
	}

	SEL selector = NSSelectorFromString(@"unityAdsShowComplete:withFinishState:");
	if ([self.wrapped respondsToSelector:selector]) {
		((void (*)(id, SEL, NSString*, NSInteger))objc_msgSend)(self.wrapped, selector, placementId, state);
	}
}

- (void)unityAdsShowFailed:(nonnull NSString *)placementId withError:(NSInteger)error withMessage:(nonnull NSString *)message {
	SEL selector = NSSelectorFromString(@"unityAdsShowFailed:withError:withMessage:");
	if ([self.wrapped respondsToSelector:selector]) {
		((void (*)(id, SEL, NSString*, NSInteger, NSString*))objc_msgSend)(self.wrapped, selector, placementId, error, message);
	}
}

- (void)unityAdsShowStart:(nonnull NSString *)placementId {
	SEL selector = NSSelectorFromString(@"unityAdsShowStart:");
	if ([self.wrapped respondsToSelector:selector]) {
		((void (*)(id, SEL, NSString*))objc_msgSend)(self.wrapped, selector, placementId);
	}
}

@end

static id patchDelegate(id __nullable showDelegate) {
	if (showDelegate == NULL) {
		return [[JTReportingShowDelegate alloc] init];
	} else if ([showDelegate class] != [JTReportingShowDelegate class] && [showDelegate class] != [JTWrappingShowDelegate class]) {
		return [[JTWrappingShowDelegate alloc] init:showDelegate];
	}
	return showDelegate;
}

static id __nullable newShowOptions(void) {
	static Class __nullable UADSShowOptions = NULL;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		UADSShowOptions = objc_lookUpClass("UADSShowOptions");
	});

	if (UADSShowOptions != NULL) {
		SEL newSelector = NSSelectorFromString(@"new");
		if ([UADSShowOptions respondsToSelector:newSelector]) {
			return ((id (*)(id, SEL))objc_msgSend)(UADSShowOptions, newSelector);
		}
	}

	return NULL;
}

static void showUnityAdWithOptions(Class UnityAds, SEL _sel, UIViewController *viewController, NSString *placementId, id options, id __nullable showDelegate) {
	if (loadCallbackWithOptions != NULL) {
		SEL showMethodWithOptionsSelector = NSSelectorFromString(@"show:placementId:options:showDelegate:");
		loadCallbackWithOptions(UnityAds, showMethodWithOptionsSelector, viewController, placementId, options, patchDelegate(showDelegate));
	}
}

static void showUnityAd(Class UnityAds, SEL sel, UIViewController *viewController, NSString *placementId, id __nullable showDelegate) {
	showUnityAdWithOptions(UnityAds, sel, viewController, placementId, newShowOptions(), showDelegate);
}

static void triggerUnityBannerDidLoad(id bannerViewManager, SEL _selector, NSString* bannerAdId) {
	if (getBannerViewWithBannerAdId != NULL) {
		id view = getBannerViewWithBannerAdId(bannerViewManager, NSSelectorFromString(@"getBannerViewWithBannerAdId:"), bannerAdId);
		if (view != NULL) {
			SEL placementIdSelector = NSSelectorFromString(@"placementId");
			if ([view respondsToSelector:placementIdSelector]) {
				NSString *placementId = ((NSString* (*)(id, SEL))objc_msgSend)(view, placementIdSelector);
				if (forwardBlockStatic && placementId) {
					forwardBlockStatic(@"banner", placementId, nil);
				}
			}
		}
	}

	if (triggerBannerDidLoad != NULL) {
		triggerBannerDidLoad(bannerViewManager, NSSelectorFromString(@"triggerBannerDidLoad:"), bannerAdId);
	}
}

static void sendUnityAdLoaded(id loadModule, SEL _selector, NSString* emptyPlacementId, NSString *bannerAdId) {
	if ([loadModule isKindOfClass:UADSBannerLoadModuleClass] && getBannerViewWithBannerAdId != NULL) {
		id view = getBannerViewWithBannerAdId(loadModule, NSSelectorFromString(@"bannerViewWithID:"), bannerAdId);
		if (view != NULL) {
			SEL placementIdSelector = NSSelectorFromString(@"placementId");
			if ([view respondsToSelector:placementIdSelector]) {
				NSString *placementId = ((NSString* (*)(id, SEL))objc_msgSend)(view, placementIdSelector);
				if (forwardBlockStatic && placementId) {
					forwardBlockStatic(@"banner", placementId, nil);
				}
			}
		}
	}

	if (sendAdLoaded != NULL) {
		sendAdLoaded(loadModule, NSSelectorFromString(@"sendAdLoadedForPlacementID:andListenerID:"), emptyPlacementId, bannerAdId);
	}
}

NS_ASSUME_NONNULL_END

@interface JusttrackObjCUnityAdsAdapter()
@end

@implementation JusttrackObjCUnityAdsAdapter

- (instancetype)init {
	self = [super init];

	return self;
}

- (void)integrateWithForwardBlock:(void (^)(NSString *eventName, NSString *placement, NSNumber * _Nullable isComplete))forwardBlock
				   reportingBlock:(void (^)(NSString *message))reportingBlock
						onSuccess:(void (^)(NSString *version))onSuccess
						onFailure:(void (^)(NSError *error))onFailure {
	forwardBlockStatic = [forwardBlock copy];
	reportingBlockStatic = [reportingBlock copy];
	
	if (bannerDelegates == nil) {
		bannerDelegates = [NSMutableDictionary dictionary];
	}

	Class UnityAds = objc_lookUpClass("UnityAds") ?: objc_lookUpClass("UnityAds.UnityAds");
	if (UnityAds == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackUnityAdsAdapter"
											 code:1101
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find UnityAds class"}];
		onFailure(error);
		return;
	}

	Class UADSBannerViewManager = objc_lookUpClass("UADSBannerViewManager");

	Class UADSLoadModule = objc_lookUpClass("UADSLoadModule");
	Class UADSBannerLoadModule = objc_lookUpClass("UADSBannerLoadModule");
	if (UADSBannerViewManager == NULL && (UADSLoadModule == NULL || UADSBannerLoadModule == NULL)) {
		NSError *error = [NSError errorWithDomain:@"JusttrackUnityAdsAdapter"
											 code:1102
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find UADSBannerViewManager or UADSLoadModule and UADSBannerLoadModule classes"}];
		onFailure(error);
		return;
	}

	if (newShowOptions() == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackUnityAdsAdapter"
											 code:1103
										 userInfo:@{NSLocalizedDescriptionKey: @"Could not find UADSShowOptions class or UADSShowOptions new"}];
		onFailure(error);
		return;
	}

	static dispatch_once_t showSwizzleToken;
	static BOOL showSwizzleSuccess = YES;
	static int showSwizzleErrorCode = 0;
	static NSString *showSwizzleErrorMessage = nil;
	dispatch_once(&showSwizzleToken, ^{
		SEL showMethodSelector = NSSelectorFromString(@"show:placementId:showDelegate:");
		SEL showMethodWithOptionsSelector = NSSelectorFromString(@"show:placementId:options:showDelegate:");
		Method showMethod = class_getClassMethod(UnityAds, showMethodSelector);
		if (showMethod != NULL) {
			method_setImplementation(showMethod, (IMP) showUnityAd);
		} else {
			showSwizzleSuccess = NO;
			showSwizzleErrorCode = 1104;
			showSwizzleErrorMessage = @"Could not find UnityAds show:placementId:showDelegate:";
			return;
		}
		Method showMethodWithOptions = class_getClassMethod(UnityAds, showMethodWithOptionsSelector);
		if (showMethodWithOptions != NULL) {
			IMP oldIMP = method_getImplementation(showMethodWithOptions);
			loadCallbackWithOptions = (LoadCallbackWithOptions) oldIMP;
			method_setImplementation(showMethodWithOptions, (IMP) showUnityAdWithOptions);
		} else {
			showSwizzleSuccess = NO;
			showSwizzleErrorCode = 1105;
			showSwizzleErrorMessage = @"Could not find UnityAds show:placementId:options:showDelegate:";
			return;
		}
	});
	if (!showSwizzleSuccess) {
		NSError *error = [NSError errorWithDomain:@"JusttrackUnityAdsAdapter"
											 code:showSwizzleErrorCode
										 userInfo:@{NSLocalizedDescriptionKey: showSwizzleErrorMessage}];
		onFailure(error);
		return;
	}

	if (UADSBannerViewManager != NULL) {
		static dispatch_once_t bannerViewManagerSwizzleToken;
		static BOOL bannerViewManagerSwizzleSuccess = YES;
		static int bannerViewManagerSwizzleErrorCode = 0;
		static NSString *bannerViewManagerSwizzleErrorMessage = nil;
		dispatch_once(&bannerViewManagerSwizzleToken, ^{
			Method triggerBannerLoadMethod = class_getInstanceMethod(UADSBannerViewManager, NSSelectorFromString(@"triggerBannerDidLoad:"));
			if (triggerBannerLoadMethod != NULL) {
				IMP oldIMP = method_getImplementation(triggerBannerLoadMethod);
				triggerBannerDidLoad = (TriggerBannerDidLoad) oldIMP;
				method_setImplementation(triggerBannerLoadMethod, (IMP) triggerUnityBannerDidLoad);
			} else {
				bannerViewManagerSwizzleSuccess = NO;
				bannerViewManagerSwizzleErrorCode = 1106;
				bannerViewManagerSwizzleErrorMessage = @"Could not find UADSBannerViewManager triggerBannerDidLoad:";
				return;
			}

			Method getBannerViewMethod = class_getInstanceMethod(UADSBannerViewManager, NSSelectorFromString(@"getBannerViewWithBannerAdId:"));
			if (getBannerViewMethod != NULL) {
				IMP oldIMP = method_getImplementation(getBannerViewMethod);
				getBannerViewWithBannerAdId = (GetBannerViewWithBannerAdId) oldIMP;
			} else {
				bannerViewManagerSwizzleSuccess = NO;
				bannerViewManagerSwizzleErrorCode = 1107;
				bannerViewManagerSwizzleErrorMessage = @"Could not find UADSBannerViewManager getBannerViewWithBannerAdId:";
				return;
			}
		});
		if (!bannerViewManagerSwizzleSuccess) {
			NSError *error = [NSError errorWithDomain:@"JusttrackUnityAdsAdapter"
												 code:bannerViewManagerSwizzleErrorCode
											 userInfo:@{NSLocalizedDescriptionKey: bannerViewManagerSwizzleErrorMessage}];
			onFailure(error);
			return;
		}
	}

	if (UADSLoadModule != NULL && UADSBannerLoadModule != NULL) {
		static dispatch_once_t loadModuleSwizzleToken;
		static BOOL loadModuleSwizzleSuccess = YES;
		static int loadModuleSwizzleErrorCode = 0;
		static NSString *loadModuleSwizzleErrorMessage = nil;
		dispatch_once(&loadModuleSwizzleToken, ^{
			UADSBannerLoadModuleClass = UADSBannerLoadModule;

			Method sendAdLoadedMethod = class_getInstanceMethod(UADSLoadModule, NSSelectorFromString(@"sendAdLoadedForPlacementID:andListenerID:"));
			if (sendAdLoadedMethod != NULL) {
				IMP oldIMP = method_getImplementation(sendAdLoadedMethod);
				sendAdLoaded = (SendAdLoaded) oldIMP;
				method_setImplementation(sendAdLoadedMethod, (IMP) sendUnityAdLoaded);
			} else {
				loadModuleSwizzleSuccess = NO;
				loadModuleSwizzleErrorCode = 1108;
				loadModuleSwizzleErrorMessage = @"Could not find UADSLoadModule sendAdLoadedForPlacementID:andListenerID:";
				return;
			}

			Method getBannerViewMethod = class_getInstanceMethod(UADSBannerLoadModule, NSSelectorFromString(@"bannerViewWithID:"));
			if (getBannerViewMethod != NULL) {
				IMP oldIMP = method_getImplementation(getBannerViewMethod);
				getBannerViewWithBannerAdId = (GetBannerViewWithBannerAdId) oldIMP;
			} else {
				loadModuleSwizzleSuccess = NO;
				loadModuleSwizzleErrorCode = 1109;
				loadModuleSwizzleErrorMessage = @"Could not find UADSBannerLoadModule bannerViewWithID:";
				return;
			}
		});
		if (!loadModuleSwizzleSuccess) {
			NSError *error = [NSError errorWithDomain:@"JusttrackUnityAdsAdapter"
												 code:loadModuleSwizzleErrorCode
											 userInfo:@{NSLocalizedDescriptionKey: loadModuleSwizzleErrorMessage}];
			onFailure(error);
			return;
		}
	}

	Class UADSBannerView = objc_lookUpClass("UADSBannerView");
	if (UADSBannerView != NULL) {
		static dispatch_once_t bannerViewSwizzleToken;
		dispatch_once(&bannerViewSwizzleToken, ^{
			SEL setDelegateSelector = NSSelectorFromString(@"setDelegate:");
			Method setDelegateMethod = class_getInstanceMethod(UADSBannerView, setDelegateSelector);
			if (setDelegateMethod != NULL) {
				IMP originalSetDelegate = method_getImplementation(setDelegateMethod);

				IMP newSetDelegate = imp_implementationWithBlock(^(id bannerView, id delegate) {
					if (delegate != nil && ![delegate isKindOfClass:[JTBannerDelegate class]]) {
						JTBannerDelegate *wrappedDelegate = [[JTBannerDelegate alloc] initWithOriginalDelegate:delegate];

						NSString *key = [NSString stringWithFormat:@"%p", bannerView];
						bannerDelegates[key] = wrappedDelegate;

						((void (*)(id, SEL, id))originalSetDelegate)(bannerView, setDelegateSelector, wrappedDelegate);
					} else {
						((void (*)(id, SEL, id))originalSetDelegate)(bannerView, setDelegateSelector, delegate);
					}
				});

				method_setImplementation(setDelegateMethod, newSetDelegate);
			}
		});
	}
	
	Method getVersionMethod = class_getClassMethod(UnityAds, NSSelectorFromString(@"getVersion"));
	if (getVersionMethod != NULL) {
		getVersion = (GetVersion) method_getImplementation(getVersionMethod);
		NSString *version = getVersion(UnityAds, NSSelectorFromString(@"getVersion"));
		onSuccess(version);
	} else {
		onSuccess(@"Unknown");
	}
}

@end