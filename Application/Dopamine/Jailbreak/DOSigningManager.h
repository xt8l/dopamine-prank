#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DOSigningManager : NSObject

+ (instancetype)sharedManager;

- (BOOL)hasP12;
- (BOOL)hasMobileprovision;
- (BOOL)hasRequiredCertificates;

- (void)saveP12FromURL:(NSURL *)url;
- (void)saveMobileprovisionFromURL:(NSURL *)url;
- (void)removeP12;
- (void)removeMobileprovision;

- (NSString *)p12DisplayName;
- (NSString *)mobileprovisionDisplayName;

- (void)startESignFromViewController:(UIViewController *)vc
                          p12Password:(NSString *)password
                             progress:(void(^)(NSString *status, float progress))progressBlock
                           completion:(void(^)(BOOL success, NSError *error))completionBlock;

@end
