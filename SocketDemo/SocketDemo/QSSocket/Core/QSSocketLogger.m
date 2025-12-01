//
//  QSSocketLogger.m
//  QSSocket
//
//  Created on 2024.
//  Copyright © 2024. All rights reserved.
//

#import "QSSocketLogger.h"

// 全局变量定义，默认关闭日志
BOOL QSSocketLogEnabled = NO;

#ifdef DEBUG
void QSSocketLog(NSString *format, ...) {
    if (QSSocketLogEnabled) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        NSLog(@"[QSSocket] %@", message);
        va_end(args);
    }
}
#endif

