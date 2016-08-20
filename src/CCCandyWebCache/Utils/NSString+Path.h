//
//  NSString+Path.h
//  Pods
//
//  Created by jw on 6/22/16.
//
//

#import <Foundation/Foundation.h>

@interface NSString (Path)

+ (NSString*)documentPath;

- (NSString*)stringWithPathRelativeTo:(NSString*)anchorPath;
@end
