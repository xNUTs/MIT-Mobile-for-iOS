#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "MITManagedObject.h"

@class MITMobiusResource;

@interface MITMobiusResourceOwner : MITManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) MITMobiusResource *resource;

@end
