#import "$(LDEDisplayName).h"

@implementation LibraryGreeter

+ (NSString *)greetingFor:(NSString *)name
{
    return [NSString stringWithFormat:@"Hello, %@!", name];
}

@end

int library_add(int a, int b)
{
    return a + b;
}
