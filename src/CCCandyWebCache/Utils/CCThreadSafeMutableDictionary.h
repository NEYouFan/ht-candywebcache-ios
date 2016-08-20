//
//  CCThreadSafeMutableDictionary.h
//  Pods
//
//  Created by jw on 7/6/16.
//
//

#import <Foundation/Foundation.h>
#import "HTFDThreadSafeMutableDictionary.h"

//@interface CCThreadSafeMutableDictionary<KeyType, ObjectType> : NSMutableDictionary<KeyType, ObjectType>
@interface CCThreadSafeMutableDictionary<KeyType, ObjectType> : HTFDThreadSafeMutableDictionary<KeyType, ObjectType>

@end
