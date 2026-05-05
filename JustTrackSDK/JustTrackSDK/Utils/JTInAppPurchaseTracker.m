#import "JTInAppPurchaseTracker.h"

NS_ASSUME_NONNULL_BEGIN

@interface JTInAppPurchaseTracker ()
@property (nonatomic, copy, nullable) void (^productsRequestCompletionHandler)(SKProduct * __nullable);
@property (nonatomic, copy, nullable) void (^transactionHandler)(NSString *, NSString * __nullable, NSInteger, NSDecimalNumber *, NSString *, bool);
@property (nonatomic, copy, nullable) void (^missingProductHandler)(NSString *);
@end

@implementation JTInAppPurchaseTracker

- (void)addTransactionObserver:(void (^)(NSString *, NSString * __nullable, NSInteger, NSDecimalNumber *, NSString *, bool))transactionHandler
         missingProductHandler:(void (^)(NSString *))missingProductHandler {
    self.transactionHandler = transactionHandler;
    self.missingProductHandler = missingProductHandler;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

- (void)removeTransactionObserver {
    self.transactionHandler = nil;
    self.missingProductHandler = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        if (transaction.transactionState != SKPaymentTransactionStatePurchased) {
            continue;
        }

        NSString *productId = transaction.payment.productIdentifier;
        NSInteger quantity = transaction.payment.quantity;
		NSString  * __nullable transactionId = transaction.transactionIdentifier;
        [self loadProductWithProductId:productId completion:^(SKProduct *product) {
            if (product != nil) {
                NSDecimalNumber *price = product.price;
                NSString *currency = product.priceLocale.currencyCode;
                bool isSubscription;
                if (@available(iOS 12.0, *)) {
                    isSubscription = product.subscriptionPeriod != nil;
                } else {
                    // hmm... don't know how to handle this, lets just assume it isn't a subscription
                    // (and we have <0.01% of users with that low versions anyway)
                    isSubscription = false;
                }
				[self handleTransactionWithProductId:productId transactionId:transactionId quantity:quantity price:price currency:currency isSubscription:isSubscription];
            } else if (self.missingProductHandler != nil) {
                self.missingProductHandler(productId);
            }
        }];
    }
}

- (void)loadProductWithProductId:(NSString *)productId completion:(void (^)(SKProduct *))completion {
    self.productsRequestCompletionHandler = completion;
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:productId]];
    request.delegate = self;
    [request start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (self.productsRequestCompletionHandler != nil) {
        if (response.products.count == 0) {
            self.productsRequestCompletionHandler(nil);
        } else {
            self.productsRequestCompletionHandler(response.products.firstObject);
        }
        self.productsRequestCompletionHandler = nil;
    }
}

- (void)handleTransactionWithProductId:(NSString *)productId
						 transactionId:(nullable NSString *)transactionId
                              quantity:(NSInteger)quantity
                                 price:(NSDecimalNumber *)price
                              currency:(NSString *)currency
                        isSubscription:(bool)isSubscription {
    if (self.transactionHandler != nil) {
		self.transactionHandler(productId, transactionId, quantity, price, currency, isSubscription);
    }
}

@end

NS_ASSUME_NONNULL_END
