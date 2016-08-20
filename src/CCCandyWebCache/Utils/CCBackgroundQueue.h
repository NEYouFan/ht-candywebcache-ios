//
//  CCBackgroundQueue.h
//  Pods
//
//  Created by jw on 7/5/16.
//
//

#import <Foundation/Foundation.h>

/**
 *  并发队列
 */
@interface CCBackgroundQueue : NSObject

+ (instancetype)sharedInstance;

- (void)dispatchAsync:(void (^)(void))block;

- (void)dispatchSync:(void (^)(void))block;

@end
