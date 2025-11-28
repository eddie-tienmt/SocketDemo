# QSSocket SDK

一个简单易用的长连接Socket SDK库，支持三种底层实现方式切换。

## 功能特性

- ✅ 支持根据IP和端口号发起连接、断开连接、读写数据
- ✅ 底层支持切换 BSD Socket、CFNetwork、NSStream 三种实现
- ✅ 通过合理的架构设计隔离底层实现，业务方无需关心底层细节
- ✅ 线程安全，网络操作在后台线程，回调在主线程
- ✅ 完善的错误处理机制

## 架构设计

```
QSSocket (对外接口)
    ↓
QSSocketFactory (工厂类)
    ↓
QSSocketProtocol (统一协议)
    ↓
┌──────────────┬──────────────┬──────────────┐
│ BSD Socket   │  CFNetwork   │   NSStream   │
│  实现类      │   实现类     │   实现类     │
└──────────────┴──────────────┴──────────────┘
```

## 快速开始

### 1. 导入头文件

```objective-c
#import "QSSocket.h"
```

### 2. 创建Socket实例

```objective-c
// 使用NSStream实现（推荐）
QSSocket *socket = [[QSSocket alloc] initWithType:QSSocketTypeNSStream];

// 或使用CFNetwork实现
QSSocket *socket = [[QSSocket alloc] initWithType:QSSocketTypeCFNetwork];

// 或使用BSD Socket实现
QSSocket *socket = [[QSSocket alloc] initWithType:QSSocketTypeBSD];
```

### 3. 设置代理

```objective-c
socket.delegate = self;
```

实现代理方法：

```objective-c
- (void)socketDidConnect:(QSSocket *)socket {
    NSLog(@"连接成功");
}

- (void)socketDidDisconnect:(QSSocket *)socket error:(NSError *)error {
    NSLog(@"断开连接: %@", error);
}

- (void)socket:(QSSocket *)socket didReceiveData:(NSData *)data {
    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"收到数据: %@", message);
}

- (void)socket:(QSSocket *)socket didFailWithError:(NSError *)error {
    NSLog(@"发生错误: %@", error);
}
```

### 4. 连接服务器

```objective-c
NSError *error = nil;
BOOL success = [socket connectToHost:@"192.168.1.100" port:8080 error:&error];
if (!success) {
    NSLog(@"连接失败: %@", error);
}
```

### 5. 发送数据

```objective-c
NSString *message = @"Hello Server";
NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
NSError *error = nil;
BOOL success = [socket sendData:data error:&error];
if (!success) {
    NSLog(@"发送失败: %@", error);
}
```

### 6. 断开连接

```objective-c
[socket disconnect];
```

## 完整示例

```objective-c
@interface ViewController () <QSSocketDelegate>
@property (nonatomic, strong) QSSocket *socket;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 创建Socket实例
    self.socket = [[QSSocket alloc] initWithType:QSSocketTypeNSStream];
    self.socket.delegate = self;
    
    // 连接服务器
    NSError *error = nil;
    [self.socket connectToHost:@"192.168.1.100" port:8080 error:&error];
    if (error) {
        NSLog(@"连接失败: %@", error);
    }
}

- (void)socketDidConnect:(QSSocket *)socket {
    NSLog(@"连接成功");
    
    // 发送数据
    NSString *message = @"Hello Server";
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    [socket sendData:data error:&error];
}

- (void)socket:(QSSocket *)socket didReceiveData:(NSData *)data {
    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"收到数据: %@", message);
}

- (void)socketDidDisconnect:(QSSocket *)socket error:(NSError *)error {
    NSLog(@"断开连接");
}

@end
```

## Socket类型说明

### QSSocketTypeNSStream (推荐)
- **优点**: 使用Cocoa层API，代码简洁，易于使用
- **适用场景**: 大多数应用场景，推荐使用

### QSSocketTypeCFNetwork
- **优点**: 基于Core Foundation，性能较好
- **适用场景**: 需要更好性能的场景

### QSSocketTypeBSD
- **优点**: 最底层控制，灵活性最高
- **适用场景**: 需要精细控制或特殊需求的场景

## 注意事项

1. 所有网络操作都在后台线程执行，回调在主线程
2. 连接、发送数据等操作都是同步的，会阻塞当前线程直到完成或超时
3. 数据接收是异步的，通过代理方法回调
4. 断开连接后需要重新创建实例才能再次连接

## 目录结构

```
QSSocket/
├── QSSocket.h                    # SDK主头文件
├── QSSocket.m                    # SDK主实现类
├── QSSocketDelegate.h            # 代理协议
├── Core/
│   ├── QSSocketProtocol.h        # 底层实现统一协议
│   ├── QSSocketFactory.h         # 工厂类
│   ├── QSSocketFactory.m
│   └── Impl/
│       ├── QSSocketBSDImpl.h     # BSD Socket实现
│       ├── QSSocketBSDImpl.m
│       ├── QSSocketCFNetworkImpl.h  # CFNetwork实现
│       ├── QSSocketCFNetworkImpl.m
│       ├── QSSocketNSStreamImpl.h   # NSStream实现
│       └── QSSocketNSStreamImpl.m
└── README.md                     # 使用说明
```

