//
//  QSSocketFactory.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QSSocketProtocol.h"

/**
 * Socket类型枚举
 */
typedef NS_ENUM(NSInteger, QSSocketType) {
    QSSocketTypeBSD,        // BSD Socket (最底层)
    QSSocketTypeCFNetwork,  // CFNetwork (Core Foundation层)
    QSSocketTypeNSStream    // NSStream (Cocoa层，推荐)
};

/**
 * Socket工厂类
 * 用于创建不同类型的Socket实现
 */
@interface QSSocketFactory : NSObject

/**
 * 创建指定类型的Socket实现实例
 * @param type Socket类型
 * @return 遵循QSSocketProtocol协议的实现实例
 */
+ (id<QSSocketProtocol>)createSocketWithType:(QSSocketType)type;

@end

