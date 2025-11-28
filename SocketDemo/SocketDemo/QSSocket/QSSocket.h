//
//  QSSocket.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QSSocketDelegate.h"
#import "Core/QSSocketFactory.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * QSSocket - 长连接Socket SDK
 * 
 * 支持三种底层实现方式：
 * - QSSocketTypeBSD: BSD Socket (最底层)
 * - QSSocketTypeCFNetwork: CFNetwork (Core Foundation层)
 * - QSSocketTypeNSStream: NSStream (Cocoa层，推荐)
 * 
 * 使用示例：
 * @code
 * QSSocket *socket = [[QSSocket alloc] initWithType:QSSocketTypeNSStream];
 * socket.delegate = self;
 * 
 * NSError *error = nil;
 * [socket connectToHost:@"192.168.1.100" port:8080 error:&error];
 * 
 * NSData *data = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];
 * [socket sendData:data error:&error];
 * 
 * [socket disconnect];
 * @endcode
 */
@interface QSSocket : NSObject

/**
 * 代理对象，用于接收连接、断开、数据接收等事件回调
 */
@property (nonatomic, weak, nullable) id<QSSocketDelegate> delegate;

/**
 * Socket类型（只读）
 */
@property (nonatomic, assign, readonly) QSSocketType socketType;

/**
 * 是否已连接（只读）
 */
@property (nonatomic, assign, readonly) BOOL isConnected;

/**
 * 初始化Socket实例
 * @param type Socket类型
 * @return Socket实例
 */
- (instancetype)initWithType:(QSSocketType)type;

/**
 * 连接到指定主机和端口
 * @param host 主机地址
 * @param port 端口号
 * @param error 错误信息指针
 * @return 是否连接成功
 */
- (BOOL)connectToHost:(NSString *)host port:(NSInteger)port error:(NSError **)error;

/**
 * 断开连接
 */
- (void)disconnect;

/**
 * 发送数据
 * @param data 要发送的数据
 * @param error 错误信息指针
 * @return 是否发送成功
 */
- (BOOL)sendData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

