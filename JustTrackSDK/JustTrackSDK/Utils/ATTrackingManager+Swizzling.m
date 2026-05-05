#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>
#import <JustTrackSDK/JustTrackSDK-Swift.h>

@implementation ATTrackingManager (JustTrackSdkSwizzling)

static NSString *const previousAuthorizationStatusKey = @"JustTrackSdkPreviousATTrackingManagerAuthorizationStatusKey";

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self justtrack_sdk_swizzleRequestTrackingAuthorization];
    });
}

+ (void)justtrack_sdk_swizzleRequestTrackingAuthorization {
    if (@available(iOS 14, *)) {
        Class class = object_getClass((id)self);
        [self justtrack_sdk_swizzleOriginalSelector:@selector(requestTrackingAuthorizationWithCompletionHandler:)
                                       withSelector:@selector(justtrack_sdk_swizzled_requestTrackingAuthorizationWithCompletionHandler:)
                                              class:class];
    }
}

+ (void)justtrack_sdk_swizzleOriginalSelector:(SEL)originalSelector
                                 withSelector:(SEL)swizzledSelector
                                        class:(Class)class {
    Method originalMethod = class_getClassMethod(class, originalSelector);
    Method swizzledMethod = class_getClassMethod(class, swizzledSelector);

    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (void)justtrack_sdk_swizzled_requestTrackingAuthorizationWithCompletionHandler:(void (^)(enum ATTrackingManagerAuthorizationStatus))completion {
    [[AdTrackingEventPublisher shared] setAdTrackingAuthorizationRequestRunning:true];
    [[AdTrackingEventPublisher shared] onRequestAdTrackingPermission];

    [self justtrack_sdk_swizzled_requestTrackingAuthorizationWithCompletionHandler:^(enum ATTrackingManagerAuthorizationStatus status) {
        ATTrackingManagerAuthorizationStatus previousStatus = [self justtrack_sdk_getPreviousAuthorizationStatus];

        switch (status) {
            case ATTrackingManagerAuthorizationStatusNotDetermined:
                break;

            case ATTrackingManagerAuthorizationStatusRestricted:
                if (previousStatus == ATTrackingManagerAuthorizationStatusNotDetermined) {
                    [[AdTrackingEventPublisher shared] onRestrictGettingAdTrackingPermission];
                } else if (previousStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
                    [[AdTrackingEventPublisher shared] onRevokeGettingAdTrackingPermission];
                }
                break;

            case ATTrackingManagerAuthorizationStatusDenied:
                if (previousStatus == ATTrackingManagerAuthorizationStatusNotDetermined) {
                    [[AdTrackingEventPublisher shared] onDenyGettingAdTrackingPermission];
                } else if (previousStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
                    [[AdTrackingEventPublisher shared] onRevokeGettingAdTrackingPermission];
                }
                break;

            case ATTrackingManagerAuthorizationStatusAuthorized:
                if (previousStatus != ATTrackingManagerAuthorizationStatusAuthorized) {
                    [[AdTrackingEventPublisher shared] onAuthorizeGettingAdTrackingPermission];
                }
                break;
        }

        completion(status);

        [[AdTrackingEventPublisher shared] setAdTrackingAuthorizationRequestRunning:false];
        [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)status forKey:previousAuthorizationStatusKey];
    }];
}

+ (ATTrackingManagerAuthorizationStatus)justtrack_sdk_getPreviousAuthorizationStatus {
    NSInteger previousStatusValue = [[NSUserDefaults standardUserDefaults] integerForKey:previousAuthorizationStatusKey];

    BOOL isValid = (previousStatusValue >= ATTrackingManagerAuthorizationStatusNotDetermined) && (previousStatusValue <= ATTrackingManagerAuthorizationStatusAuthorized);

    if (isValid) {
        return (ATTrackingManagerAuthorizationStatus)previousStatusValue;
    } else {
        return ATTrackingManagerAuthorizationStatusNotDetermined;
    }
}

@end
