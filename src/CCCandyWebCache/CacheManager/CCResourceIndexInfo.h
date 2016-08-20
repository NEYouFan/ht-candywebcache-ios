//
//  CCResourceIndexInfo.h
//  Pods
//
//  Created by jw on 6/8/16.
//
//

#import <Foundation/Foundation.h>

/**
 *  资源检索信息
 */
@interface CCResourceIndexInfo : NSObject

/**
 *  资源相对URL。如kaola/js/core.js
 */
@property (nonatomic, copy) NSString* url;

/**
 *  资源本地路径
 */
//@property (nonatomic, copy) NSString* localPath;
/**
 *  资源本地相对路径，相对于Document目录
 */
@property (nonatomic, copy) NSString* localRelativePath;

/**
 *  资源本地全路径
 */
@property (nonatomic, copy, readonly) NSString* localFullPath;

/**
 *  资源md5值
 */
@property (nonatomic, copy) NSString* md5;

/**
 *  资源所属webapp名称
 */
@property (nonatomic, copy) NSString* webappName;


/**
 *  唯一key
 *
 *  @return webappName/url
 */
- (NSString*)uniqueKey;

@end
