//
//  QSSocketError.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * QSSocket错误域
 */
FOUNDATION_EXPORT NSString * const QSSocketErrorDomain;

/**
 * QSSocket错误码枚举
 */
typedef NS_ENUM(NSInteger, QSSocketErrorCode) {
    // 配置错误 (1000-1999)
    QSSocketErrorCodeInvalidHost = 1000,          // 主机地址为空或无效
    QSSocketErrorCodeInvalidPort = 1001,           // 端口号无效
    QSSocketErrorCodeEmptyData = 1002,            // 数据为空
    QSSocketErrorCodeAlreadyConnected = 1003,    // 已经连接
    
    // 连接错误 (2000-2999)
    QSSocketErrorCodeConnectionTimeout = 2000,   // 连接超时
    QSSocketErrorCodeConnectionFailed = 2001,    // 连接失败
    QSSocketErrorCodeHostResolutionFailed = 2002, // 地址解析失败
    QSSocketErrorCodeCreateSocketFailed = 2003,   // 创建socket失败
    QSSocketErrorCodeCreateStreamFailed = 2004,   // 创建流失败
    QSSocketErrorCodeOpenStreamFailed = 2005,     // 打开流失败
    QSSocketErrorCodeSetCallbackFailed = 2006,    // 设置回调失败
    
    // 读写错误 (3000-3999)
    QSSocketErrorCodeSendFailed = 3000,          // 发送失败
    QSSocketErrorCodeReceiveFailed = 3001,         // 接收失败
    QSSocketErrorCodeSendIncomplete = 3002,      // 数据未完全发送
    QSSocketErrorCodeSendTimeout = 3003,         // 发送超时
    QSSocketErrorCodeReadError = 3004,           // 读取数据错误
    
    // 状态错误 (4000-4999)
    QSSocketErrorCodeNotConnected = 4000,        // 未连接
    QSSocketErrorCodeConnectionClosed = 4001     // 连接已关闭
};

/**
 * QSSocket错误处理类
 * 提供统一的错误创建和描述方法
 */
@interface QSSocketError : NSObject

/**
 * 创建NSError对象
 * @param code 错误码
 * @param userInfo 额外的用户信息（可选）
 * @return NSError对象
 */
+ (NSError *)errorWithCode:(QSSocketErrorCode)code userInfo:(nullable NSDictionary *)userInfo;

/**
 * 创建NSError对象（带底层错误信息）
 * @param code 错误码
 * @param underlyingError 底层错误（如系统错误）
 * @param userInfo 额外的用户信息（可选）
 * @return NSError对象
 */
+ (NSError *)errorWithCode:(QSSocketErrorCode)code underlyingError:(nullable NSError *)underlyingError userInfo:(nullable NSDictionary *)userInfo;

/**
 * 获取错误码的本地化描述
 * @param code 错误码
 * @return 错误描述字符串
 */
+ (NSString *)localizedDescriptionForCode:(QSSocketErrorCode)code;

/**
 * 判断错误码是否属于配置错误范围
 * @param code 错误码
 * @return 是否为配置错误
 */
+ (BOOL)isConfigError:(QSSocketErrorCode)code;

/**
 * 判断错误码是否属于连接错误范围
 * @param code 错误码
 * @return 是否为连接错误
 */
+ (BOOL)isConnectionError:(QSSocketErrorCode)code;

/**
 * 判断错误码是否属于读写错误范围
 * @param code 错误码
 * @return 是否为读写错误
 */
+ (BOOL)isReadWriteError:(QSSocketErrorCode)code;

/**
 * 判断错误码是否属于状态错误范围
 * @param code 错误码
 * @return 是否为状态错误
 */
+ (BOOL)isStateError:(QSSocketErrorCode)code;

@end

NS_ASSUME_NONNULL_END

