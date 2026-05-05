#import "JTLimitedReferenceRetainer.h"

@interface JTLimitedReferenceRetainer ()
@property (nonatomic, strong, nonnull) NSMutableDictionary* store;
@property (nonatomic) unsigned long nextIndex;
@property (nonatomic) unsigned long capacity;
@end

@implementation JTLimitedReferenceRetainer

- (id)init:(unsigned long)capacity {
    self = [super init];

    if (self != NULL) {
        self.store = [[NSMutableDictionary alloc] init];
        self.nextIndex = 0;
        self.capacity = capacity;
    }

    return self;
}

- (unsigned long)retain:(id)reference {
    @synchronized (self) {
        long index = self.nextIndex++;
        long keyIndex = index % self.capacity;

        NSNumber *key = [[NSNumber alloc] initWithLong:keyIndex];
        [self.store setObject:reference forKey:key];

        return index;
    }
}

- (void)release:(unsigned long)index {
    long keyIndex = index % self.capacity;
    NSNumber *key = [[NSNumber alloc] initWithLong:keyIndex];
    @synchronized (self) {
        [self.store removeObjectForKey:key];
    }
}

@end
