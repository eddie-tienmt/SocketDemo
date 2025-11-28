//
//  QSSocket.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocket.h"
#import "Core/QSSocketProtocol.h"
#import "Core/QSSocketError.h"

@interface QSSocket () {
    id<QSSocketProtocol> _socketImpl;
    QSSocketType _socketType;
}

@end

@implementation QSSocket

- (instancetype)init {
    // 默认使用NSStream
    return [self initWithType:QSSocketTypeNSStream];
}

- (instancetype)initWithType:(QSSocketType)type {
    self = [super init];
    if (self) {
        _socketType = type;
        _socketImpl = [QSSocketFactory createSocketWithType:type];
        
        // 设置数据接收回调
        __weak typeof(self) weakSelf = self;
        [_socketImpl setReceiveDataCallback:^(NSData *data) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(socket:didReceiveData:)]) {
                [strongSelf.delegate socket:strongSelf didReceiveData:data];
            }
        }];
        
        // 设置连接状态变化回调
        [_socketImpl setConnectionStateCallback:^(BOOL connected, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (strongSelf.delegate) {
                if (connected) {
                    if ([strongSelf.delegate respondsToSelector:@selector(socketDidConnect:)]) {
                        [strongSelf.delegate socketDidConnect:strongSelf];
                    }
                } else {
                    if ([strongSelf.delegate respondsToSelector:@selector(socketDidDisconnect:error:)]) {
                        [strongSelf.delegate socketDidDisconnect:strongSelf error:error];
                    }
                    
                    if (error && [strongSelf.delegate respondsToSelector:@selector(socket:didFailWithError:)]) {
                        [strongSelf.delegate socket:strongSelf didFailWithError:error];
                    }
                }
            }
        }];
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
}

#pragma mark - Public Methods

- (BOOL)connectToHost:(NSString *)host port:(NSInteger)port error:(NSError **)error {
    if (!host || host.length == 0) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeInvalidHost userInfo:nil];
        }
        return NO;
    }
    
    if (port <= 0 || port > 65535) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeInvalidPort userInfo:nil];
        }
        return NO;
    }
    
    return [_socketImpl connectToHost:host port:port error:error];
}

- (void)disconnect {
    [_socketImpl disconnect];
}

- (BOOL)sendData:(NSData *)data error:(NSError **)error {
    if (!data || data.length == 0) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeEmptyData userInfo:nil];
        }
        return NO;
    }
    
    return [_socketImpl sendData:data error:error];
}

- (BOOL)isConnected {
    return [_socketImpl isConnected];
}

@end

