#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PSSpecifierCellType) {
    PSGroupCell = 0,
    PSLinkCell = 1,
    PSLinkListCell = 2,
    PSListItemCell = 3,
    PSTitleValueCell = 4,
    PSSliderCell = 5,
    PSSwitchCell = 6,
    PSStaticTextCell = 7,
    PSEditTextCell = 8,
    PSSegmentCell = 9,
    PSGiantIconCell = 10,
    PSGiantCell = 11,
    PSSecureEditTextCell = 12,
    PSButtonCell = 13,
    PSEditTextViewCell = 14,
    PSSpinnerCell = 15
};

@interface PSSpecifier : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, retain) id target;
@property (nonatomic) SEL getter;
@property (nonatomic) SEL setter;
@property (nonatomic) NSInteger cellType;
@property (nonatomic, retain) Class detailControllerClass;
@property (nonatomic, retain) Class editPaneClass;

+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)setter get:(SEL)getter detail:(Class)detail cell:(NSInteger)cellType edit:(Class)edit;
+ (instancetype)emptyGroupSpecifier;
+ (instancetype)groupSpecifierWithName:(NSString *)name;

- (void)setProperty:(id)property forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;

@end
