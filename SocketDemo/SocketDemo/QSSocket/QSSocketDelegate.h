//
//  QSSocketDelegate.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>

@class QSSocket;

/**
 * QSSocket 代理协议
 * 用于接收连接、断开、数据接收等事件回调
 */
@protocol QSSocketDelegate <NSObject>

@optional

/**
 * Socket连接成功回调
 * @param socket Socket实例
 */
- (void)socketDidConnect:(QSSocket *)socket;

/**
 * Socket断开连接回调
 * @param socket Socket实例
 * @param error 断开原因，如果为nil表示正常断开
 */
- (void)socketDidDisconnect:(QSSocket *)socket error:(NSError *)error;

/**
 * Socket接收到数据回调
 * @param socket Socket实例
 * @param data 接收到的数据
 */
- (void)socket:(QSSocket *)socket didReceiveData:(NSData *)data;

/**
 * Socket发生错误回调
 * @param socket Socket实例
 * @param error 错误信息
 */
- (void)socket:(QSSocket *)socket didFailWithError:(NSError *)error;

@end

