#import "JTALReferenceRetainer.h"

@interface JTALReferenceRetainer ()
@property (nonatomic, strong, nonnull) NSMutableDictionary* store;
@property (nonatomic) unsigned long nextIndex;
- (id) init;
@end

@implementation JTALReferenceRetainer

+ (JTALReferenceRetainer *)shared {
    static JTALReferenceRetainer* instance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[JTALReferenceRetainer alloc] init];
    });

    return instance;
}

- (id)init {
    self = [super init];

    if (self != NULL) {
        self.store = [[NSMutableDictionary alloc] init];
        self.nextIndex = 0;
    }

    return self;
}

- (unsigned long)retain:(id)reference {
    @synchronized (self) {
        unsigned long index = self.nextIndex++;

        NSNumber *key = [[NSNumber alloc] initWithUnsignedLong:index];
        [self.store setObject:reference forKey:key];

        return index;
    }
}

- (void)release:(unsigned long)index {
    NSNumber *key = [[NSNumber alloc] initWithUnsignedLong:index];
    @synchronized (self) {
        [self.store removeObjectForKey:key];
    }
}

@end
