//
//  main.m
//  Dopamine
//
//  Fake version - no jailbreak functionality
//

#import <UIKit/UIKit.h>
#import "DOAppDelegate.h"

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        appDelegateClassName = NSStringFromClass([DOAppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
