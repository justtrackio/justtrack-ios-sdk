#ifndef JTLimitedReferenceRetainer_h
#define JTLimitedReferenceRetainer_h

#import <Foundation/Foundation.h>

/// A thread-safe class to store references to objects.
/// The memory for objects stored with retain will not be released until you call release again
/// or the internal capacity is exceeded (working in a round-robin fashion).
@interface JTLimitedReferenceRetainer : NSObject
/// Create a new reference retainer with at most capacity entries stored.
- (id) init: (unsigned long) capacity;
/// Retain stores a reference in the retainer. It returns an index you have to release later.
- (unsigned long) retain: (id)reference;
/// Release removes the reference stored with retain. It is safe to call release multiple times with the same index.
- (void) release: (unsigned long)index;
@end

#endif /* JTLimitedReferenceRetainer_h */
