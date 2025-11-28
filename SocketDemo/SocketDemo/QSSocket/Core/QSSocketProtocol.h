//
//  QSSocketProtocol.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QSSocket;

/**
 * Socket底层实现统一协议
 * 所有底层实现类必须遵循此协议
 */
@protocol QSSocketProtocol <NSObject>

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

/**
 * 是否已连接
 * @return 连接状态
 */
- (BOOL)isConnected;

/**
 * 设置数据接收回调
 * @param callback 数据接收回调block
 */
- (void)setReceiveDataCallback:(void(^)(NSData *data))callback;

/**
 * 设置连接状态变化回调
 * @param callback 连接状态变化回调block (connected: YES表示连接成功, NO表示断开)
 */
- (void)setConnectionStateCallback:(void(^)(BOOL connected, NSError *error))callback;

@end

