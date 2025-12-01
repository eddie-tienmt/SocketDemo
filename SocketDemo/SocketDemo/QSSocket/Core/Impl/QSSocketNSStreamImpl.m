//
//  QSSocketNSStreamImpl.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocketNSStreamImpl.h"
#import "../QSSocketError.h"
#import "../QSSocketLogger.h"

#define kBufferSize 1024

@interface QSSocketNSStreamImpl () <NSStreamDelegate> {
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    NSThread *_networkThread;
    
    NSString *_host;
    NSInteger _port;
    BOOL _isConnected;
    
    void(^_receiveDataCallback)(NSData *data);
    void(^_connectionStateCallback)(BOOL connected, NSError *error);
}

@end

@implementation QSSocketNSStreamImpl

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
            QSSocketLog(@"[NSStream] 开始创建流连接");
            
            // 创建流
            [NSStream getStreamsToHostWithName:host
                                           port:(NSInteger)port
                                    inputStream:&self->_inputStream
                                   outputStream:&self->_outputStream];
            
            if (!self->_inputStream || !self->_outputStream) {
                connectError = [QSSocketError errorWithCode:QSSocketErrorCodeCreateStreamFailed userInfo:nil];
                QSSocketLog(@"[NSStream] 创建流失败");
                dispatch_semaphore_signal(semaphore);
                return;
            }
            QSSocketLog(@"[NSStream] 流创建成功");
            
            // 设置代理
            self->_inputStream.delegate = self;
            self->_outputStream.delegate = self;
            
            // 将流添加到RunLoop
            [self->_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [self->_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            
            // 打开流
            QSSocketLog(@"[NSStream] 开始打开流");
            [self->_inputStream open];
            [self->_outputStream open];
            
            // 等待连接完成
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            
            // 检查连接状态
            NSStreamStatus inputStatus = self->_inputStream.streamStatus;
            NSStreamStatus outputStatus = self->_outputStream.streamStatus;
            
            if (inputStatus == NSStreamStatusOpen && outputStatus == NSStreamStatusOpen) {
                connectSuccess = YES;
                self->_isConnected = YES;
                QSSocketLog(@"[NSStream] 连接成功");
            } else if (inputStatus == NSStreamStatusError || outputStatus == NSStreamStatusError) {
                NSError *streamError = self->_inputStream.streamError ?: self->_outputStream.streamError;
                if (streamError) {
                    connectError = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed underlyingError:streamError userInfo:nil];
                    QSSocketLog(@"[NSStream] 连接失败: %@", streamError.localizedDescription);
                } else {
                    connectError = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed userInfo:nil];
                    QSSocketLog(@"[NSStream] 连接失败");
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
                QSSocketLog(@"[NSStream] RunLoop开始运行");
                [runLoop run];
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
    
    QSSocketLog(@"[NSStream] 开始断开连接");
    _isConnected = NO;
    
    if (_inputStream) {
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_inputStream close];
        _inputStream.delegate = nil;
        _inputStream = nil;
        QSSocketLog(@"[NSStream] 输入流已关闭");
    }
    
    if (_outputStream) {
        [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream close];
        _outputStream.delegate = nil;
        _outputStream = nil;
        QSSocketLog(@"[NSStream] 输出流已关闭");
    }
    
    // 停止RunLoop
    if (_networkThread && ![_networkThread isFinished]) {
        [self performSelector:@selector(stopRunLoop) onThread:_networkThread withObject:nil waitUntilDone:NO];
    }
    
    // 回调断开连接
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_connectionStateCallback(NO, nil);
        });
    }
}

- (BOOL)sendData:(NSData *)data error:(NSError **)error {
    if (!_isConnected || !_outputStream) {
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
    
    QSSocketLog(@"[NSStream] 开始发送数据, size=%lu", (unsigned long)data.length);
    NSInteger bytesWritten = [_outputStream write:data.bytes maxLength:data.length];
    
    if (bytesWritten == -1) {
        NSError *streamError = _outputStream.streamError;
        if (error) {
            if (streamError) {
                *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendFailed underlyingError:streamError userInfo:nil];
            } else {
                *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendFailed userInfo:nil];
            }
        }
        QSSocketLog(@"[NSStream] 发送数据失败: %@", streamError ? streamError.localizedDescription : @"未知错误");
        return NO;
    } else if (bytesWritten != data.length) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendIncomplete userInfo:nil];
        }
        QSSocketLog(@"[NSStream] 数据未完全发送: 期望%lu, 实际%ld", (unsigned long)data.length, bytesWritten);
        return NO;
    }
    
    QSSocketLog(@"[NSStream] 数据发送成功: %ld bytes", bytesWritten);
    return YES;
}

- (BOOL)isConnected {
    return _isConnected && _inputStream && _outputStream;
}

- (void)setReceiveDataCallback:(void(^)(NSData *data))callback {
    _receiveDataCallback = callback;
}

- (void)setConnectionStateCallback:(void(^)(BOOL connected, NSError *error))callback {
    _connectionStateCallback = callback;
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            // 流打开完成
            break;
        }
            
        case NSStreamEventHasBytesAvailable: {
            // 有数据可读
            if (stream == _inputStream) {
                uint8_t buffer[kBufferSize];
                NSInteger bytesRead = [_inputStream read:buffer maxLength:kBufferSize];
                
                if (bytesRead > 0) {
                    QSSocketLog(@"[NSStream] 接收到数据: %ld bytes", bytesRead);
                    NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
                    if (_receiveDataCallback) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self->_receiveDataCallback(data);
                        });
                    }
                } else if (bytesRead == 0) {
                    // 流结束
                    QSSocketLog(@"[NSStream] 流结束 (bytesRead=0)");
                    [self handleStreamEnd];
                } else {
                    // 读取错误
                    NSError *streamError = _inputStream.streamError;
                    NSError *error = nil;
                    if (streamError) {
                        error = [QSSocketError errorWithCode:QSSocketErrorCodeReadError underlyingError:streamError userInfo:nil];
                        QSSocketLog(@"[NSStream] 读取数据错误: %@", streamError.localizedDescription);
                    } else {
                        error = [QSSocketError errorWithCode:QSSocketErrorCodeReadError userInfo:nil];
                        QSSocketLog(@"[NSStream] 读取数据错误");
                    }
                    [self handleConnectionError:error];
                }
            }
            break;
        }
            
        case NSStreamEventHasSpaceAvailable: {
            // 可以写入数据
            break;
        }
            
        case NSStreamEventErrorOccurred: {
            // 发生错误
            NSError *streamError = stream.streamError;
            NSError *error = nil;
            if (streamError) {
                error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed underlyingError:streamError userInfo:nil];
                QSSocketLog(@"[NSStream] 流错误: %@", streamError.localizedDescription);
            } else {
                error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed userInfo:nil];
                QSSocketLog(@"[NSStream] 流错误");
            }
            [self handleConnectionError:error];
            break;
        }
            
        case NSStreamEventEndEncountered: {
            // 流结束
            [self handleStreamEnd];
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Private Methods

- (void)stopRunLoop {
    CFRunLoopStop(CFRunLoopGetCurrent());
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

