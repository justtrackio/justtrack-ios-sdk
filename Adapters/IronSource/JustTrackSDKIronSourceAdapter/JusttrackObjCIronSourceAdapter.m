#import "JusttrackObjCIronSourceAdapter.h"
#import "JusttrackISImpressionDataDelegate.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface JusttrackObjCIronSourceAdapter()
@end

@implementation JusttrackObjCIronSourceAdapter

- (instancetype)init {
	self = [super init];
	
	return self;
}

- (void)integrateImpressionDataBlock:(JusttrackISImpressionDataBlock)impressionDataBlock
						   onSuccess:(void (^)(void))onSuccess
						   onFailure:(void (^)(NSError *error))onFailure {
	Class LevelPlayClass = objc_lookUpClass("LevelPlay");

	if (LevelPlayClass == NULL) {
		NSError *error = [NSError errorWithDomain:@"JusttrackIronSourceAdapter"
											 code:1101
										 userInfo:@{NSLocalizedDescriptionKey: @"LevelPlay SDK not found"}];
		onFailure(error);
		return;
	}

	JusttrackISImpressionDataDelegate *delegate = [[JusttrackISImpressionDataDelegate alloc] initWithImpressionDataBlock:impressionDataBlock];

	SEL addDelegateSelector = NSSelectorFromString(@"addImpressionDataDelegate:");
	if ([LevelPlayClass respondsToSelector:addDelegateSelector]) {
		((void (*)(id, SEL, id))objc_msgSend)(LevelPlayClass, addDelegateSelector, delegate);
		onSuccess();
	} else {
		NSError *error = [NSError errorWithDomain:@"JusttrackIronSourceAdapter"
											 code:1102
										 userInfo:@{NSLocalizedDescriptionKey: @"LevelPlay addImpressionDataDelegate method not available"}];
		onFailure(error);
	}
}

@end
