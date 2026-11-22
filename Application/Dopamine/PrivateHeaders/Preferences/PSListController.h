#import <UIKit/UIKit.h>
#import "PSSpecifier.h"

@interface PSListController : UITableViewController {
    UITableView *_table;
}

@property (nonatomic, retain) NSMutableArray *specifiers;

- (PSSpecifier *)specifierForID:(NSString *)identifier;
- (PSSpecifier *)specifier;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifiers;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)afterSpecifier animated:(BOOL)animated;
- (void)removeSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;

@end
