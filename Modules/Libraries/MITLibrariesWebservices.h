#import <Foundation/Foundation.h>
#import <ISO8601DateFormatterValueTransformer/ISO8601DateFormatterValueTransformer.h>

extern NSInteger const kMITLibrariesSearchResultsLimit;

@class MITLibrariesWorldcatItem, MITLibrariesUser, MITLibrariesAskUsModel, MITLibrariesMITIdentity;

@interface MITLibrariesWebservices : NSObject

+ (NSDictionary *)formSheetGroupsAsHTMLParametersDictionary:(NSArray *)formSheetGroups;

+ (void)postTellUsFormForParameters:(NSDictionary *)parameters withCompletion:(void(^)(id responseObject, NSError *error))completion;
+ (void)postAskUsFormForParameters:(NSDictionary *)parameters withCompletion:(void(^)(id responseObject, NSError *error))completion;

+ (void)getLinksWithCompletion:(void (^)(NSArray *links, NSError *error))completion;
+ (void)getLibrariesWithCompletion:(void (^)(NSArray *libraries, NSError *error))completion;
+ (void)getAskUsTopicsWithCompletion:(void (^)(MITLibrariesAskUsModel *askUs, NSError *error))completion;
+ (void)getResultsForSearch:(NSString *)searchString
              startingIndex:(NSInteger)startingIndex
                completion:(void (^)(NSArray *items, NSError *error))completion;
+ (void)getItemDetailsForItem:(MITLibrariesWorldcatItem *)item
                   completion:(void (^)(MITLibrariesWorldcatItem *item, NSError *error))completion;
+ (void)getUserWithCompletion:(void (^)(MITLibrariesUser *user, NSError *error))completion;
+ (void)getMITIdentityInBackgroundWithCompletion:(void(^)(MITLibrariesMITIdentity *identity, NSError *error))completion;

+ (NSArray *)recentSearchStrings;
+ (void)clearRecentSearches;

+ (RKISO8601DateFormatter *)librariesDateFormatter;

@end
