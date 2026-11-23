#import <Foundation/Foundation.h>

@interface DOZipHelper : NSObject
+ (BOOL)unzipFileAtPath:(NSString *)zipPath toDirectory:(NSString *)destDir error:(NSError **)error;
+ (BOOL)createZipAtPath:(NSString *)zipPath fromDirectory:(NSString *)sourceDir error:(NSError **)error;
@end
