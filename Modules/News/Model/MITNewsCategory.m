#import "MITNewsCategory.h"
#import "MITNewsStory.h"


@implementation MITNewsCategory

@dynamic identifier;
@dynamic lastUpdated;
@dynamic url;
@dynamic name;
@dynamic stories;

+ (NSString*)entityName
{
    return @"NewsCategory";
}
@end