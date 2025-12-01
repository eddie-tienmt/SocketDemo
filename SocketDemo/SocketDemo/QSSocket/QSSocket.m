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
#import "Core/QSSocketLogger.h"

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
        
        NSString *typeName = @"Unknown";
        switch (type) {
            case QSSocketTypeBSD:
                typeName = @"BSD Socket";
                break;
            case QSSocketTypeCFNetwork:
                typeName = @"CFNetwork";
                break;
            case QSSocketTypeNSStream:
                typeName = @"NSStream";
                break;
        }
        QSSocketLog(@"[Init] initWithType:%@", typeName);
        
        // 设置数据接收回调
        __weak typeof(self) weakSelf = self;
        [_socketImpl setReceiveDataCallback:^(NSData *data) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                QSSocketLog(@"[Receive] didReceiveData:接收数据 %lu bytes", (unsigned long)data.length);
                if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(socket:didReceiveData:)]) {
                    [strongSelf.delegate socket:strongSelf didReceiveData:data];
                }
            }
        }];
        
        // 设置连接状态变化回调
        [_socketImpl setConnectionStateCallback:^(BOOL connected, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (strongSelf.delegate) {
                if (connected) {
                    QSSocketLog(@"[Success] socketDidConnect:连接成功");
                    if ([strongSelf.delegate respondsToSelector:@selector(socketDidConnect:)]) {
                        [strongSelf.delegate socketDidConnect:strongSelf];
                    }
                } else {
                    if (error) {
                        QSSocketLog(@"[Error] socketDidDisconnect:断开连接 - %@ (Code:%ld)", error.localizedDescription, (long)error.code);
                    } else {
                        QSSocketLog(@"[Disconnect] socketDidDisconnect:正常断开连接");
                    }
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
    QSSocketLog(@"[Connect] connectToHost:%@:%ld", host, port);
    
    if (!host || host.length == 0) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeInvalidHost userInfo:nil];
        }
        QSSocketLog(@"[Error] connectToHost:主机地址为空");
        return NO;
    }
    
    if (port <= 0 || port > 65535) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeInvalidPort userInfo:nil];
        }
        QSSocketLog(@"[Error] connectToHost:端口号无效 - %ld", port);
        return NO;
    }
    
    BOOL result = [_socketImpl connectToHost:host port:port error:error];
    if (!result && error && *error) {
        QSSocketLog(@"[Error] connectToHost:连接失败 - %@ (Code:%ld)", (*error).localizedDescription, (long)(*error).code);
    }
    return result;
}

- (void)disconnect {
    QSSocketLog(@"[Disconnect] disconnect:断开连接");
    [_socketImpl disconnect];
}

- (BOOL)sendData:(NSData *)data error:(NSError **)error {
    if (!data || data.length == 0) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeEmptyData userInfo:nil];
        }
        QSSocketLog(@"[Error] sendData:数据为空");
        return NO;
    }
    
    QSSocketLog(@"[Send] sendData:发送数据 %lu bytes", (unsigned long)data.length);
    BOOL result = [_socketImpl sendData:data error:error];
    if (result) {
        QSSocketLog(@"[Success] sendData:发送成功");
    } else if (error && *error) {
        QSSocketLog(@"[Error] sendData:发送失败 - %@ (Code:%ld)", (*error).localizedDescription, (long)(*error).code);
    }
    return result;
}

- (BOOL)isConnected {
    return [_socketImpl isConnected];
}

@end

