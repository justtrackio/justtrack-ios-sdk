#import <Foundation/Foundation.h>

@interface SignalSimulator : NSObject

+ (void)trigger_sigbus;
+ (void)trigger_sigsegv;
+ (void)trigger_sigpipe;

@end
