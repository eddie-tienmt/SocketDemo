//
//  QSSocketBSDImpl.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../QSSocketProtocol.h"

/**
 * BSD Socket实现类
 * 使用最底层的BSD Socket API
 */
@interface QSSocketBSDImpl : NSObject <QSSocketProtocol>

@end

