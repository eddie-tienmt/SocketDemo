//
//  QSSocketError.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocketError.h"

NSString * const QSSocketErrorDomain = @"QSSocketErrorDomain";

@implementation QSSocketError

+ (NSError *)errorWithCode:(QSSocketErrorCode)code userInfo:(nullable NSDictionary *)userInfo {
    NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
    
    // 添加默认描述
    NSString *defaultDescription = [self localizedDescriptionForCode:code];
    if (defaultDescription) {
        mutableUserInfo[NSLocalizedDescriptionKey] = defaultDescription;
    }
    
    // 合并用户提供的信息
    if (userInfo) {
        [mutableUserInfo addEntriesFromDictionary:userInfo];
    }
    
    return [NSError errorWithDomain:QSSocketErrorDomain code:code userInfo:[mutableUserInfo copy]];
}

+ (NSError *)errorWithCode:(QSSocketErrorCode)code underlyingError:(nullable NSError *)underlyingError userInfo:(nullable NSDictionary *)userInfo {
    NSMutableDictionary *mutableUserInfo = [NSMutableDictionary dictionary];
    
    // 添加默认描述
    NSString *defaultDescription = [self localizedDescriptionForCode:code];
    if (defaultDescription) {
        mutableUserInfo[NSLocalizedDescriptionKey] = defaultDescription;
    }
    
    // 添加底层错误信息
    if (underlyingError) {
        mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
        // 如果有底层错误的描述，也添加进去
        if (underlyingError.localizedDescription) {
            NSString *combinedDescription = [NSString stringWithFormat:@"%@: %@", defaultDescription ?: @"", underlyingError.localizedDescription];
            mutableUserInfo[NSLocalizedDescriptionKey] = combinedDescription;
        }
    }
    
    // 合并用户提供的信息
    if (userInfo) {
        [mutableUserInfo addEntriesFromDictionary:userInfo];
    }
    
    return [NSError errorWithDomain:QSSocketErrorDomain code:code userInfo:[mutableUserInfo copy]];
}

+ (NSString *)localizedDescriptionForCode:(QSSocketErrorCode)code {
    switch (code) {
        // 配置错误
        case QSSocketErrorCodeInvalidHost:
            return @"主机地址为空或无效";
        case QSSocketErrorCodeInvalidPort:
            return @"端口号无效";
        case QSSocketErrorCodeEmptyData:
            return @"数据为空";
        case QSSocketErrorCodeAlreadyConnected:
            return @"已经连接，请先断开";
            
        // 连接错误
        case QSSocketErrorCodeConnectionTimeout:
            return @"连接超时";
        case QSSocketErrorCodeConnectionFailed:
            return @"连接失败";
        case QSSocketErrorCodeHostResolutionFailed:
            return @"地址解析失败";
        case QSSocketErrorCodeCreateSocketFailed:
            return @"创建socket失败";
        case QSSocketErrorCodeCreateStreamFailed:
            return @"创建流失败";
        case QSSocketErrorCodeOpenStreamFailed:
            return @"打开流失败";
        case QSSocketErrorCodeSetCallbackFailed:
            return @"设置回调失败";
            
        // 读写错误
        case QSSocketErrorCodeSendFailed:
            return @"发送失败";
        case QSSocketErrorCodeReceiveFailed:
            return @"接收失败";
        case QSSocketErrorCodeSendIncomplete:
            return @"数据未完全发送";
        case QSSocketErrorCodeSendTimeout:
            return @"发送超时";
        case QSSocketErrorCodeReadError:
            return @"读取数据错误";
            
        // 状态错误
        case QSSocketErrorCodeNotConnected:
            return @"未连接";
        case QSSocketErrorCodeConnectionClosed:
            return @"连接已关闭";
            
        default:
            return @"未知错误";
    }
}

+ (BOOL)isConfigError:(QSSocketErrorCode)code {
    return code >= 1000 && code < 2000;
}

+ (BOOL)isConnectionError:(QSSocketErrorCode)code {
    return code >= 2000 && code < 3000;
}

+ (BOOL)isReadWriteError:(QSSocketErrorCode)code {
    return code >= 3000 && code < 4000;
}

+ (BOOL)isStateError:(QSSocketErrorCode)code {
    return code >= 4000 && code < 5000;
}

@end

