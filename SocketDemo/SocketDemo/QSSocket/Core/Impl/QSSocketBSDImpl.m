//
//  QSSocketBSDImpl.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocketBSDImpl.h"
#import "../QSSocketError.h"
#import "../QSSocketLogger.h"
#import <arpa/inet.h>
#import <netdb.h>
#import <sys/socket.h>

#define kBufferSize 1024

@interface QSSocketBSDImpl () {
    int _socketFileDescriptor;
    NSString *_host;
    NSInteger _port;
    BOOL _isConnected;
    BOOL _shouldReceiveData;
    NSThread *_receiveThread;
    
    void(^_receiveDataCallback)(NSData *data);
    void(^_connectionStateCallback)(BOOL connected, NSError *error);
}

@end

@implementation QSSocketBSDImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        _socketFileDescriptor = -1;
        _isConnected = NO;
        _shouldReceiveData = NO;
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        QSSocketLog(@"[BSD] 开始创建socket连接");
        
        // 创建socket
        self->_socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0);
        if (-1 == self->_socketFileDescriptor) {
            NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]}];
            connectError = [QSSocketError errorWithCode:QSSocketErrorCodeCreateSocketFailed underlyingError:underlyingError userInfo:nil];
            QSSocketLog(@"[BSD] 创建socket失败: %s", strerror(errno));
            dispatch_semaphore_signal(semaphore);
            return;
        }
        QSSocketLog(@"[BSD] socket创建成功, fd=%d", self->_socketFileDescriptor);
        
        // 解析主机地址
        QSSocketLog(@"[BSD] 开始解析主机地址: %@", host);
        struct hostent *remoteHostEnt = gethostbyname([host UTF8String]);
        if (NULL == remoteHostEnt) {
            close(self->_socketFileDescriptor);
            self->_socketFileDescriptor = -1;
            NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]}];
            connectError = [QSSocketError errorWithCode:QSSocketErrorCodeHostResolutionFailed underlyingError:underlyingError userInfo:nil];
            QSSocketLog(@"[BSD] 地址解析失败: %s", strerror(errno));
            dispatch_semaphore_signal(semaphore);
            return;
        }
        QSSocketLog(@"[BSD] 地址解析成功");
        
        struct in_addr *remoteInAddr = (struct in_addr *)remoteHostEnt->h_addr_list[0];
        
        // 设置socket参数
        struct sockaddr_in socketParameters;
        socketParameters.sin_family = AF_INET;
        socketParameters.sin_addr = *remoteInAddr;
        socketParameters.sin_port = htons((uint16_t)port);
        
        // 连接socket
        QSSocketLog(@"[BSD] 开始连接socket");
        int ret = connect(self->_socketFileDescriptor, (struct sockaddr *)&socketParameters, sizeof(socketParameters));
        if (-1 == ret) {
            close(self->_socketFileDescriptor);
            self->_socketFileDescriptor = -1;
            NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]}];
            connectError = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionFailed underlyingError:underlyingError userInfo:nil];
            QSSocketLog(@"[BSD] socket连接失败: %s", strerror(errno));
            dispatch_semaphore_signal(semaphore);
            return;
        }
        
        // 设置socket为非阻塞模式（可选，这里保持阻塞模式）
        // 设置接收超时
        struct timeval timeout;
        timeout.tv_sec = 5;
        timeout.tv_usec = 0;
        setsockopt(self->_socketFileDescriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        
        connectSuccess = YES;
        self->_isConnected = YES;
        self->_shouldReceiveData = YES;
        
        QSSocketLog(@"[BSD] socket连接成功, fd=%d", self->_socketFileDescriptor);
        dispatch_semaphore_signal(semaphore);
        
        // 启动数据接收线程
        [self startReceiveThread];
        
        // 回调连接成功
        if (self->_connectionStateCallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_connectionStateCallback(YES, nil);
            });
        }
    });
    
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
    if (!_isConnected && _socketFileDescriptor == -1) {
        return;
    }
    
    QSSocketLog(@"[BSD] 开始断开连接, fd=%d", _socketFileDescriptor);
    _shouldReceiveData = NO;
    _isConnected = NO;
    
    if (_socketFileDescriptor != -1) {
        close(_socketFileDescriptor);
        _socketFileDescriptor = -1;
        QSSocketLog(@"[BSD] socket已关闭");
    }
    
    // 等待接收线程结束
    if (_receiveThread && ![_receiveThread isFinished]) {
        [self performSelector:@selector(stopReceiveThread) onThread:_receiveThread withObject:nil waitUntilDone:NO];
    }
    
    // 回调断开连接
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_connectionStateCallback(NO, nil);
        });
    }
}

- (BOOL)sendData:(NSData *)data error:(NSError **)error {
    if (!_isConnected || _socketFileDescriptor == -1) {
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
    
    __block BOOL sendSuccess = NO;
    __block NSError *sendError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        QSSocketLog(@"[BSD] 开始发送数据, size=%lu, fd=%d", (unsigned long)data.length, self->_socketFileDescriptor);
        ssize_t bytesSent = send(self->_socketFileDescriptor, data.bytes, data.length, 0);
        if (bytesSent == -1) {
            NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]}];
            sendError = [QSSocketError errorWithCode:QSSocketErrorCodeSendFailed underlyingError:underlyingError userInfo:nil];
            QSSocketLog(@"[BSD] 发送数据失败: %s", strerror(errno));
        } else if (bytesSent != data.length) {
            sendError = [QSSocketError errorWithCode:QSSocketErrorCodeSendIncomplete userInfo:nil];
            QSSocketLog(@"[BSD] 数据未完全发送: 期望%lu, 实际%zd", (unsigned long)data.length, bytesSent);
        } else {
            sendSuccess = YES;
            QSSocketLog(@"[BSD] 数据发送成功: %zd bytes", bytesSent);
        }
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
    long result = dispatch_semaphore_wait(semaphore, timeout);
    
    if (result != 0) {
        if (error) {
            *error = [QSSocketError errorWithCode:QSSocketErrorCodeSendTimeout userInfo:nil];
        }
        return NO;
    }
    
    if (!sendSuccess) {
        if (error) {
            *error = sendError;
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)isConnected {
    return _isConnected && _socketFileDescriptor != -1;
}

- (void)setReceiveDataCallback:(void(^)(NSData *data))callback {
    _receiveDataCallback = callback;
}

- (void)setConnectionStateCallback:(void(^)(BOOL connected, NSError *error))callback {
    _connectionStateCallback = callback;
}

#pragma mark - Private Methods

- (void)startReceiveThread {
    if (_receiveThread && ![_receiveThread isFinished]) {
        return;
    }
    
    _receiveThread = [[NSThread alloc] initWithTarget:self selector:@selector(receiveDataLoop) object:nil];
    [_receiveThread start];
}

- (void)receiveDataLoop {
    @autoreleasepool {
        QSSocketLog(@"[BSD] 数据接收线程启动");
        while (_shouldReceiveData && _isConnected && _socketFileDescriptor != -1) {
            char buffer[kBufferSize];
            ssize_t bytesRead = recv(_socketFileDescriptor, buffer, kBufferSize, 0);
            
            if (bytesRead > 0) {
                QSSocketLog(@"[BSD] 接收到数据: %zd bytes", bytesRead);
                NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
                if (_receiveDataCallback) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self->_receiveDataCallback(data);
                    });
                }
            } else if (bytesRead == 0) {
                // 连接已关闭
                QSSocketLog(@"[BSD] 连接已关闭 (recv返回0)");
                [self handleConnectionClosed];
                break;
            } else {
                // 错误
                if (errno != EAGAIN && errno != EWOULDBLOCK) {
                    NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]}];
                    NSError *error = [QSSocketError errorWithCode:QSSocketErrorCodeReadError underlyingError:underlyingError userInfo:nil];
                    QSSocketLog(@"[BSD] 接收数据错误: %s", strerror(errno));
                    [self handleConnectionError:error];
                    break;
                }
            }
            
            // 短暂休眠，避免CPU占用过高
            usleep(10000); // 10ms
        }
        QSSocketLog(@"[BSD] 数据接收线程结束");
    }
}

- (void)stopReceiveThread {
    _shouldReceiveData = NO;
}

- (void)handleConnectionClosed {
    _isConnected = NO;
    if (_socketFileDescriptor != -1) {
        close(_socketFileDescriptor);
        _socketFileDescriptor = -1;
    }
    
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [QSSocketError errorWithCode:QSSocketErrorCodeConnectionClosed userInfo:nil];
            self->_connectionStateCallback(NO, error);
        });
    }
}

- (void)handleConnectionError:(NSError *)error {
    _isConnected = NO;
    if (_socketFileDescriptor != -1) {
        close(_socketFileDescriptor);
        _socketFileDescriptor = -1;
    }
    
    if (_connectionStateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_connectionStateCallback(NO, error);
        });
    }
}

@end

