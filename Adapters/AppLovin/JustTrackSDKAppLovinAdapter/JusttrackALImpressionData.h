#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JusttrackALImpressionData : NSObject
@property (nonatomic, strong) NSString *format;
@property (nonatomic, strong) NSString *network;
@property (nonatomic, strong) NSString *placement;
@property (nonatomic, strong) NSNumber *revenue;
@end

typedef void (^JusttrackALImpressionDataBlock)(JusttrackALImpressionData *impressionData);

NS_ASSUME_NONNULL_END
