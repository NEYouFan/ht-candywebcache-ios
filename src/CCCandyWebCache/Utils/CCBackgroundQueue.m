//
//  CCBackgroundQueue.m
//  Pods
//
//  Created by jw on 7/5/16.
//
//

#import "CCBackgroundQueue.h"

static const void * const kDispatchQueueSpecificKey = &kDispatchQueueSpecificKey;


@interface CCBackgroundQueue ()

@property (nonatomic, strong) dispatch_queue_t queue;

@end


@implementation CCBackgroundQueue



+ (instancetype)sharedInstance
{
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [CCBackgroundQueue new];
    });
    return instance;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
       _queue = dispatch_queue_create([[NSString stringWithFormat:@"cccachemanager.%@", self] UTF8String], DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_set_specific(_queue, kDispatchQueueSpecificKey, (__bridge void *)self, NULL);
    }
    return self;
}

- (void)dispatchAsync:(void (^)(void))block
{
    dispatch_async(_queue, ^{
        if (block) {
            block();
        }
    });
}

- (void)dispatchSync:(void (^)(void))block
{
    CCBackgroundQueue *currentSyncQueue = (__bridge id)dispatch_get_specific(kDispatchQueueSpecificKey);
    assert(currentSyncQueue != self && "dispatchSync: was called reentrantly on the same queue, which would lead to a deadlock");

    dispatch_sync(_queue, ^{
        if (block) {
            block();
        }
    });
}

@end
