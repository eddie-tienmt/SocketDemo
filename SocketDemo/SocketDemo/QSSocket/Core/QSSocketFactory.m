//
//  QSSocketFactory.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocketFactory.h"
#import "Impl/QSSocketBSDImpl.h"
#import "Impl/QSSocketCFNetworkImpl.h"
#import "Impl/QSSocketNSStreamImpl.h"

@implementation QSSocketFactory

+ (id<QSSocketProtocol>)createSocketWithType:(QSSocketType)type {
    switch (type) {
        case QSSocketTypeBSD:
            return [[QSSocketBSDImpl alloc] init];
            
        case QSSocketTypeCFNetwork:
            return [[QSSocketCFNetworkImpl alloc] init];
            
        case QSSocketTypeNSStream:
            return [[QSSocketNSStreamImpl alloc] init];
            
        default:
            // 默认使用NSStream
            return [[QSSocketNSStreamImpl alloc] init];
    }
}

@end

