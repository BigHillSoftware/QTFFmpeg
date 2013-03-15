//
//  QTFFLog.h
//  QTFFmpeg
//
//  Created by Brad O'Hearne on 3/14/13.
//  Copyright (c) 2013 Big Hill Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QTFFAppLogFile.h"

#ifdef DEBUG
//#   define QTFFAppLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#   define QTFFAppLog(fmt, ...) { NSString *vQTFFAppLogMessage = [NSString stringWithFormat:(@"" fmt), ##__VA_ARGS__]; QTFFAppLogFile *vQTFFAppLogLogFile = [QTFFAppLogFile sharedAppLogFile]; [vQTFFAppLogLogFile log:vQTFFAppLogMessage]; NSLog(@"%@", vQTFFAppLogMessage); }
#else
//#   define QTFFAppLog(fmt, ...) { NSString *message = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; QTFFAppLogFile *logFile = [QTFFAppLogFile sharedAppLogFile]; [logFile log:message]; }
#   define QTFFAppLog(fmt, ...) { NSString *vQTFFAppLogMessage = [NSString stringWithFormat:(@"" fmt), ##__VA_ARGS__]; QTFFAppLogFile *vQTFFAppLogLogFile = [QTFFAppLogFile sharedAppLogFile]; [vQTFFAppLogLogFile log:vQTFFAppLogMessage]; }
#endif
