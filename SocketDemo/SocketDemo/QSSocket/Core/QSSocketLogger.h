//
//  QSSocketLogger.h
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 日志开关全局变量
 * 默认关闭，需要手动开启：QSSocketLogEnabled = YES;
 */
extern BOOL QSSocketLogEnabled;

/**
 * QSSocket日志函数
 * 仅在DEBUG环境下有效，Release环境下会被宏移除
 * 
 * 使用示例：
 * @code
 * // 开启日志
 * QSSocketLogEnabled = YES;
 * 
 * // 使用日志
 * QSSocketLog(@"[Connect] connectToHost:%@:%ld", host, port);
 * QSSocketLog(@"[Success] connectToHost:连接成功");
 * QSSocketLog(@"[Error] connectToHost:连接失败 - %@", error.localizedDescription);
 * @endcode
 */
#ifdef DEBUG
    void QSSocketLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
#else
    #define QSSocketLog(format, ...)
#endif

NS_ASSUME_NONNULL_END

