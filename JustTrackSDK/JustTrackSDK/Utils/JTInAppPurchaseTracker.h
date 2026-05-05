#ifndef JTInAppPurchaseTracker_h
#define JTInAppPurchaseTracker_h

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface JTInAppPurchaseTracker : NSObject<SKPaymentTransactionObserver, SKProductsRequestDelegate>
- (void)addTransactionObserver:(void (^)(NSString *, NSString * __nullable, NSInteger, NSDecimalNumber *, NSString *, bool))transactionHandler
         missingProductHandler:(void (^)(NSString *))missingProductHandler;
- (void)removeTransactionObserver;
@end

NS_ASSUME_NONNULL_END

#endif /* JTInAppPurchaseTracker_h */
