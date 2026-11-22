#import <Foundation/Foundation.h>

@interface LSApplicationProxy : NSObject

@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSArray *claimedURLSchemes;

+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;

@end
