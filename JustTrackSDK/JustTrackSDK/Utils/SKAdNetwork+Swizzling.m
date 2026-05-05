#import <objc/runtime.h>
#import <StoreKit/StoreKit.h>

@implementation SKAdNetwork (JustTrackSdkSwizzling)

static NSString * const postbackConversionValueSetKey = @"io.justtrack.postback.conversionValueSetKey";

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self justtrack_sdk_swizzlePostbackMethods];
    });
}

+ (void)justtrack_sdk_swizzlePostbackMethods {
    Class class = object_getClass((id)self);
    
    if (@available(iOS 16.1, *)) {
        [self justtrack_sdk_swizzleOriginalSelector:@selector(updatePostbackConversionValue:coarseValue:completionHandler:)
                                       withSelector:@selector(justtrack_sdk_swizzled_updatePostbackConversionValue:coarseValue:completionHandler:)
                                              class:class];
        
        [self justtrack_sdk_swizzleOriginalSelector:@selector(updatePostbackConversionValue:coarseValue:lockWindow:completionHandler:)
                                       withSelector:@selector(justtrack_sdk_swizzled_updatePostbackConversionValue:coarseValue:lockWindow:completionHandler:)
                                              class:class];
    }
    
    if (@available(iOS 15.4, *)) {
        [self justtrack_sdk_swizzleOriginalSelector:@selector(updatePostbackConversionValue:completionHandler:)
                                       withSelector:@selector(justtrack_sdk_swizzled_updatePostbackConversionValue:completionHandler:)
                                              class:class];
    }
    
    if (@available(iOS 14.0, *)) {
        [self justtrack_sdk_swizzleOriginalSelector:@selector(updateConversionValue:)
                                       withSelector:@selector(justtrack_sdk_swizzled_updateConversionValue:)
                                              class:class];
    }
    
    if (@available(iOS 11.3, *)) {
        [self justtrack_sdk_swizzleOriginalSelector:@selector(registerAppForAdNetworkAttribution)
                                       withSelector:@selector(justtrack_sdk_swizzled_registerAppForAdNetworkAttribution)
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

+ (void)justtrack_sdk_swizzled_updatePostbackConversionValue:(NSInteger)conversionValue
                                                 coarseValue:(NSInteger)coarseValue
                                           completionHandler:(void (^)(NSError * _Nullable error))completionHandler {
    [self justtrack_sdk_swizzled_updatePostbackConversionValue:conversionValue
                                                   coarseValue:coarseValue
                                             completionHandler:completionHandler];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:postbackConversionValueSetKey];
}

+ (void)justtrack_sdk_swizzled_updatePostbackConversionValue:(NSInteger)conversionValue
                                                 coarseValue:(NSInteger)coarseValue
                                                  lockWindow:(BOOL)lockWindow
                                           completionHandler:(void (^)(NSError * _Nullable error))completionHandler {
    [self justtrack_sdk_swizzled_updatePostbackConversionValue:conversionValue
                                                   coarseValue:coarseValue
                                                    lockWindow:lockWindow
                                             completionHandler:completionHandler];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:postbackConversionValueSetKey];
}

+ (void)justtrack_sdk_swizzled_updatePostbackConversionValue:(NSInteger)conversionValue
                                           completionHandler:(void (^)(NSError * _Nullable error))completionHandler {
    [self justtrack_sdk_swizzled_updatePostbackConversionValue:conversionValue
                                             completionHandler:completionHandler];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:postbackConversionValueSetKey];
}

+ (void)justtrack_sdk_swizzled_updateConversionValue:(NSInteger)conversionValue {
    [self justtrack_sdk_swizzled_updateConversionValue:conversionValue];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:postbackConversionValueSetKey];
}

+ (void)justtrack_sdk_swizzled_registerAppForAdNetworkAttribution {
    [self justtrack_sdk_swizzled_registerAppForAdNetworkAttribution];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:postbackConversionValueSetKey];
}

@end
