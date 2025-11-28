//
//  QSSocketNSStreamImpl.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../QSSocketProtocol.h"

/**
 * NSStream实现类
 * 使用Cocoa层的NSStream API（推荐使用）
 */
@interface QSSocketNSStreamImpl : NSObject <QSSocketProtocol>

@end

