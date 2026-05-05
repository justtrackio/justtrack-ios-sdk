#ifndef JTALReferenceRetainer_h
#define JTALReferenceRetainer_h

#import <Foundation/Foundation.h>

/// A thread-safe class to store references to objects in the global scope.
/// The memory for objects stored with retain will not be released until you call release again.
@interface JTALReferenceRetainer : NSObject
+ (JTALReferenceRetainer*) shared;
/// Retain stores a reference in the retainer. It returns an index you have to release later.
- (unsigned long) retain: (id)reference;
/// Release removes the reference stored with retain. It is safe to call release multiple times with the same index.
- (void) release: (unsigned long)index;
@end

#endif /* JTALReferenceRetainer_h */
