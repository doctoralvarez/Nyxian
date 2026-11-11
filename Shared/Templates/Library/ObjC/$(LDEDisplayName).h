#import <Foundation/Foundation.h>

/* An Objective-C dynamic library: built as lib$(LDEDisplayName).dylib */

@interface LibraryGreeter : NSObject
+ (NSString *)greetingFor:(NSString *)name;
@end

int library_add(int a, int b);
