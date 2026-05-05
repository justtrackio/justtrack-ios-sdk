#ifndef JusttrackISImpressionDataDelegate_h
#define JusttrackISImpressionDataDelegate_h

#import <Foundation/Foundation.h>

@interface JusttrackISImpressionData : NSObject
@property (nonatomic, strong) NSString *adUnit;
@property (nonatomic, strong) NSString *adNetwork;
@property (nonatomic, strong) NSString *placement;
@property (nonatomic, strong) NSString *abTesting;
@property (nonatomic, strong) NSString *segmentName;
@property (nonatomic, strong) NSString *instanceName;
@property (nonatomic, strong) NSNumber *revenue;
@end

typedef void (^JusttrackISImpressionDataBlock)(JusttrackISImpressionData *impressionData);

@interface JusttrackISImpressionDataDelegate : NSObject

@property (nonatomic, copy) JusttrackISImpressionDataBlock impressionDataBlock;

- (instancetype)initWithImpressionDataBlock:(JusttrackISImpressionDataBlock)block;
- (void)impressionDataDidSucceed:(id)impressionData;

@end

#endif /* JusttrackISImpressionDataDelegate_h */
