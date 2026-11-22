//
//  EnvironmentManager.h
//  Dopamine
//
//  Fake version - no real jailbreak functionality
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DOEnvironmentManager : NSObject {
    BOOL _isJailbroken;
    NSString *_jailbrokenVersion;
}

@property (nonatomic, readonly) BOOL isJailbroken;
@property (nonatomic, readonly) NSString *jailbrokenVersion;

+ (instancetype)sharedManager;

- (NSString *)appVersion;
- (NSString *)appVersionDisplayString;
- (NSString *)nightlyHash;

- (BOOL)isInstalledThroughTrollStore;
- (BOOL)isJailbroken;
- (BOOL)isJailbrokenWithOtherJailbreak;
- (BOOL)isBootstrapped;
- (NSString *)jailbrokenVersion;
- (NSString *)systemVersion;

- (BOOL)isSupported;
- (BOOL)isArm64e;
- (BOOL)isSPTM;
- (NSString *)versionSupportString;

- (void)setJailbroken:(BOOL)jailbroken withVersion:(NSString *)version;

- (void)respring;
- (void)rebootUserspace;
- (void)reboot;

- (BOOL)isJailbreakHidden;

- (BOOL)isTweakInjectionEnabled;
- (void)setTweakInjectionEnabled:(BOOL)enabled;

- (void)deleteBootstrap;

- (void)changeMobilePassword:(NSString *)newPassword;
- (void)refreshJailbreakApps;
- (NSError *)updateBootLogo;
- (NSError *)updateEnvironment;
- (void)updateJailbreakFromTIPA:(NSString *)path;

- (BOOL)isIDownloadEnabled;
- (void)setIDownloadLoaded:(BOOL)loaded needsUnsandbox:(BOOL)needsUnsandbox;

- (void)rebuildIconCache;
- (NSError *)reinstallPackageManagers;

- (BOOL)isPACBypassRequired;
- (BOOL)isPPLBypassRequired;

@end

NS_ASSUME_NONNULL_END
