//
//  QSSocketCFNetworkImpl.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocketCFNetworkImpl.h"
#import "../QSSocketError.h"
#import "../QSSocketLogger.h"
#import <CoreFoundation/CoreFoundation.h>

#define kBufferSize 1024

// 前向声明回调函数
static void socketCallback(CFReadStreamRef stream, CFStreamEventType event, void *myPtr);

@interface QSSocketCFNetworkImpl () {
    CFReadStreamRef _readStream;
    CFWriteStreamRef _writeStream;
    CFRunLoopRef _runLoop;
    NSThread *_networkThread;
    
    NSString *_host;
    NSInteger _port;
    BOOL _isConnected;
    
    void(^_receiveDataCallback)(NSData *data);
    void(^_connectionStateCallback)(BOOL connected, NSError *error);
}

@end

@implementation QSSocketCFNetworkImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        _isConnected = NO;
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
}

#pragma mark - QSSocketProtocol

- (BOOL)connectToHost:(NSString *)host port:(NSInteger)port error:(NSError **)error {
    if (_isConnected) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeAlreadyConnected userInfo:nil];
        }
        return NO;
    }
    
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
    
    _host = host;
    _port = port;
    
    // 在后台线程执行连接
    __block BOOL connectSuccess = NO;
    __block NSError *connectError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    _networkThread = [[NSThread alloc] initWithBlock:^{
        @autoreleasepool {
            QSSocketLog(@"[CFNetwork] 开始创建socket流连接");
            
            // 创建socket流
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                               (__bridge CFStringRef)host,
                                               (UInt32)port,
                                               &self->_readStream,
                                               &self->_writeStream);
            
            if (!self->_readStream || !self->_writeStream) {
                connectError = [QSSocketError errorWithCode:QSSocketErrorCodeCreateStreamFailed userInfo:nil];
                QSSocketLog(@"[CFNetwork] 创建流失败");
                dispatch_semaphore_signal(semaphore);
                return;
            }
            QSSocketLog(@"[CFNetwork] 流创建成功");
            
            // 设置客户端上下文
            CFStreamClientContext ctx = {0, (__bridge void *)(self), NULL, NULL, NULL};
            CFOptionFlags registeredEvents = (kCFStreamEventOpenCompleted |
                                              kCFStreamEventHasBytesAvailable |
                                              kCFStreamEventCanAcceptBytes |
                                              kCFStreamEventErrorOccurred |
                                              kCFStreamEventEndEncountered);
            
            // 设置读取流回调
            if (CFReadStreamSetClient(self->_readStream, registeredEvents, socketCallback, &ctx)) {
                CFReadStreamScheduleWithRunLoop(self->_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                QSSocketLog(@"[CFNetwork] 回调设置成功");
            } else {
                connectError = [QSSocketError errorWithCode:QSSocketErrorCodeSetCallbackFailed userInfo:nil];
                QSSocketLog(@"[CFNetwork] 设置回调失败");
                CFReadStreamClose(self->_readStream);
                CFWriteStreamClose(self->_writeStream);
                CFRelease(self->_readStream);
                CFRelease(self->_writeStream);
                self->_readStream = NULL;
                self->_writeStream = NULL;
                dispatch_semaphore_signal(semaphore);
                return;
            }
            
            // 打开流
            QSSocketLog(@"[CFNetwork] 开始打开流");
            if (!CFReadStreamOpen(self->_readStream) || !CFWriteStreamOpen(self->_writeStream)) {
                connectError = [QSSocketError errorWithCode:QSSocketErrorCodeOpenStreamFailed userInfo:nil];
                QSSocketLog(@"[CFNetwork] 打开流失败");
                CFReadStreamClose(self->_readStream);
                CFWriteStreamClose(self->_writeStream);
                CFRelease(self->_readStream);
                CFRelease(self->_writeStream);
                self->_readStream = NULL;
                self->_writeStream = NULL;
                dispatch_semaphore_signal(semaphore);
                return;
            }
            
            self->_runLoop = CFRunLoopGetCurrent();
            
            // 等待连接完成
            CFStreamStatus readStatus = CFReadStreamGetStatus(self->_readStream);
            CFStreamStatus writeStatus = CFWriteStreamGetStatus(self->_writeStream);
            
            // 检查连接状态
            if (readStatus == kCFStreamStatusOpen && writeStatus == kCFStreamStatusOpen) {
                connectSuccess = YES;
                self->_isConnected = YES;
                QSSocketLog(@"[CFNetwork] 连接成功");
            } else if (readStatus == kCFStreamStatusError || writeStatus == kCFStreamStatusError) {
                CFErrorRef errorRef = CFReadStreamCopyError(self->_readStream);
                if (!errorRef) {
                    errorRef = CFWriteStreamCopyError(self->_writeStream);
                }
                if (errorRef) {
                    NSString *errorDesc = (__bridge NSString *)CFErrorCopyDescription(errorRef);
                    NSError *underlyingError = [NSError errorWithDomain:(__bridge NSString *)CFErrorGetDomain(errorRef) code:CFErrorGetCode(errorRef) userInfo:@{NSLocalizedDescriptionKey: errorDesc ?: @""}];
                    connectError = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed underlyingError:underlyingError userInfo:nil];
                    QSSocketLog(@"[CFNetwork] 连接失败: %@", errorDesc);
                    CFRelease(errorRef);
                } else {
                    connectError = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed userInfo:nil];
                    QSSocketLog(@"[CFNetwork] 连接失败");
                }
            }
            
            dispatch_semaphore_signal(semaphore);
            
            if (connectSuccess) {
                // 回调连接成功
                if (self->_connectionStateCallback) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_connectionStateCallback(YES, nil);
                    });
                }
                
                // 运行RunLoop
                QSSocketLog(@"[CFNetwork] RunLoop开始运行");
                CFRunLoopRun();
            }
        }
    }];
    
    [_networkThread start];
    
    // 等待连接完成（最多等待5秒）
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
    long result = dispatch_semaphore_wait(semaphore, timeout);
    
    if (result != 0) {
        // 超时
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionTimeout userInfo:nil];
        }
        return NO;
    }
    
    if (!connectSuccess) {
        if (error) {
            *error = connectError;
        }
        return NO;
    }
    
    return YES;
}

- (void)disconnect {
    if (!_isConnected) {
        return;
    }
    
    QSSocketLog(@"[CFNetwork] 开始断开连接");
    _isConnected = NO;
    
    if (_readStream) {
        CFReadStreamUnscheduleFromRunLoop(_readStream, _runLoop, kCFRunLoopCommonModes);
        CFReadStreamClose(_readStream);
        CFRelease(_readStream);
        _readStream = NULL;
        QSSocketLog(@"[CFNetwork] 读取流已关闭");
    }
    
    if (_writeStream) {
        CFWriteStreamClose(_writeStream);
        CFRelease(_writeStream);
        _writeStream = NULL;
        QSSocketLog(@"[CFNetwork] 写入流已关闭");
    }
    
    if (_runLoop) {
        CFRunLoopStop(_runLoop);
        _runLoop = NULL;
        QSSocketLog(@"[CFNetwork] RunLoop已停止");
    }
    
    // 回调断开连接
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_connectionStateCallback(NO, nil);
        });
    }
}

- (BOOL)sendData:(NSData *)data error:(NSError **)error {
    if (!_isConnected || !_writeStream) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeNotConnected userInfo:nil];
        }
        return NO;
    }
    
    if (!data || data.length == 0) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeEmptyData userInfo:nil];
        }
        return NO;
    }
    
    QSSocketLog(@"[CFNetwork] 开始发送数据, size=%lu", (unsigned long)data.length);
    CFIndex bytesWritten = CFWriteStreamWrite(_writeStream, data.bytes, data.length);
    
    if (bytesWritten == -1) {
        CFErrorRef errorRef = CFWriteStreamCopyError(_writeStream);
        if (errorRef) {
            NSString *errorDesc = (__bridge NSString *)CFErrorCopyDescription(errorRef);
            NSError *underlyingError = [NSError errorWithDomain:(__bridge NSString *)CFErrorGetDomain(errorRef) code:CFErrorGetCode(errorRef) userInfo:@{NSLocalizedDescriptionKey: errorDesc ?: @""}];
            if (error) {
                *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendFailed underlyingError:underlyingError userInfo:nil];
            }
            QSSocketLog(@"[CFNetwork] 发送数据失败: %@", errorDesc);
            CFRelease(errorRef);
        } else {
            if (error) {
                *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendFailed userInfo:nil];
            }
            QSSocketLog(@"[CFNetwork] 发送数据失败");
        }
        return NO;
    } else if (bytesWritten != data.length) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendIncomplete userInfo:nil];
        }
        QSSocketLog(@"[CFNetwork] 数据未完全发送: 期望%lu, 实际%ld", (unsigned long)data.length, bytesWritten);
        return NO;
    }
    
    QSSocketLog(@"[CFNetwork] 数据发送成功: %ld bytes", bytesWritten);
    return YES;
}

- (BOOL)isConnected {
    return _isConnected && _readStream && _writeStream;
}

- (void)setReceiveDataCallback:(void(^)(NSData *data))callback {
    _receiveDataCallback = callback;
}

- (void)setConnectionStateCallback:(void(^)(BOOL connected, NSError *error))callback {
    _connectionStateCallback = callback;
}

#pragma mark - Private Methods

- (void)handleStreamEvent:(CFStreamEventType)event {
    switch (event) {
        case kCFStreamEventOpenCompleted: {
            // 连接打开完成
            break;
        }
            
        case kCFStreamEventHasBytesAvailable: {
            // 有数据可读
            while (CFReadStreamHasBytesAvailable(_readStream)) {
                UInt8 buffer[kBufferSize];
                CFIndex bytesRead = CFReadStreamRead(_readStream, buffer, kBufferSize);
                
                if (bytesRead > 0) {
                    QSSocketLog(@"[CFNetwork] 接收到数据: %ld bytes", bytesRead);
                    NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
                    if (_receiveDataCallback) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self->_receiveDataCallback(data);
                        });
                    }
                } else if (bytesRead == 0) {
                    // 流结束
                    QSSocketLog(@"[CFNetwork] 流结束 (bytesRead=0)");
                    [self handleStreamEnd];
                    break;
                } else {
                    // 读取错误
                    CFErrorRef errorRef = CFReadStreamCopyError(_readStream);
                    NSError *error = nil;
                    if (errorRef) {
                        NSString *errorDesc = (__bridge NSString *)CFErrorCopyDescription(errorRef);
                        NSError *underlyingError = [NSError errorWithDomain:(__bridge NSString *)CFErrorGetDomain(errorRef) code:CFErrorGetCode(errorRef) userInfo:@{NSLocalizedDescriptionKey: errorDesc ?: @""}];
                        error = [QSSocketError errorWithCode:QSSocketErrorCodeReadError underlyingError:underlyingError userInfo:nil];
                        QSSocketLog(@"[CFNetwork] 读取数据错误: %@", errorDesc);
                        CFRelease(errorRef);
                    } else {
                        error = [QSSocketError errorWithCode:QSSocketErrorCodeReadError userInfo:nil];
                        QSSocketLog(@"[CFNetwork] 读取数据错误");
                    }
                    [self handleConnectionError:error];
                    break;
                }
            }
            break;
        }
            
        case kCFStreamEventCanAcceptBytes: {
            // 可以写入数据
            break;
        }
            
        case kCFStreamEventErrorOccurred: {
            // 发生错误
            CFErrorRef errorRef = CFReadStreamCopyError(_readStream);
            if (!errorRef) {
                errorRef = CFWriteStreamCopyError(_writeStream);
            }
            NSError *error = nil;
            if (errorRef) {
                NSString *errorDesc = (__bridge NSString *)CFErrorCopyDescription(errorRef);
                NSError *underlyingError = [NSError errorWithDomain:(__bridge NSString *)CFErrorGetDomain(errorRef) code:CFErrorGetCode(errorRef) userInfo:@{NSLocalizedDescriptionKey: errorDesc ?: @""}];
                error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed underlyingError:underlyingError userInfo:nil];
                QSSocketLog(@"[CFNetwork] 流错误: %@", errorDesc);
                CFRelease(errorRef);
            } else {
                error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed userInfo:nil];
                QSSocketLog(@"[CFNetwork] 流错误");
            }
            [self handleConnectionError:error];
            break;
        }
            
        case kCFStreamEventEndEncountered: {
            // 流结束
            [self handleStreamEnd];
            break;
        }
            
        default:
            break;
    }
}

- (void)handleStreamEnd {
    _isConnected = NO;
    
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionClosed userInfo:nil];
            self->_connectionStateCallback(NO, error);
        });
    }
    
    [self disconnect];
}

- (void)handleConnectionError:(NSError *)error {
    _isConnected = NO;
    
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_connectionStateCallback(NO, error);
        });
    }
    
    [self disconnect];
}

@end

// C回调函数
static void socketCallback(CFReadStreamRef stream, CFStreamEventType event, void *myPtr) {
    QSSocketCFNetworkImpl *impl = (__bridge QSSocketCFNetworkImpl *)myPtr;
    [impl handleStreamEvent:event];
}

