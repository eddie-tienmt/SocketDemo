//
//  QSSocketCFNetworkImpl.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../QSSocketProtocol.h"

/**
 * CFNetwork实现类
 * 使用Core Foundation层的CFNetwork API
 */
@interface QSSocketCFNetworkImpl : NSObject <QSSocketProtocol>

@end

