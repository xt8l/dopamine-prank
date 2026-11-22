#import <UIKit/UIKit.h>
#import "PSSpecifier.h"

@interface PSListController : UITableViewController {
    UITableView *_table;
    NSMutableArray *_specifiers;
}

@property (nonatomic, retain) NSMutableArray *specifiers;

- (PSSpecifier *)specifierForID:(NSString *)identifier;
- (PSSpecifier *)specifier;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifiers;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)afterSpecifier animated:(BOOL)animated;
- (void)removeSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)insertContiguousSpecifiers:(NSArray *)specifiers afterSpecifier:(PSSpecifier *)afterSpecifier animated:(BOOL)animated;
- (void)removeContiguousSpecifiers:(NSArray *)specifiers animated:(BOOL)animated;
- (BOOL)containsSpecifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;

@end
