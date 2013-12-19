#import "MITMobile.h"
#import <RestKit/RKHTTPUtilities.h>

#import "CoreDataManager.h"

#import "MITMapModelController.h"
#import "MITMobileResource.h"
#import "MITMobileServerConfiguration.h"

#pragma mark - Route Definitions
#pragma mark /calendars
NSString* const MITMobileCalendars = @"apis/calendars";
NSString* const MITMobileCalendar = @"apis/calendars/:calendar";
NSString* const MITMobileCalendarEvents = @"apis/calendars/:calendar/events";
NSString* const MITMobileCalendarEvent = @"apis/calendars/:calendar/events/:event";

#pragma mark /dining
NSString* const MITMobileDining = @"apis/dining";
NSString* const MITMobileDiningVenueIcon = @"apis/dining/venues/:type/:venue/icon";
NSString* const MITMobileDiningHouseVenues = @"apis/dining/venues/house";
NSString* const MITMobileDiningRetailVenues = @"apis/dining/venues/retail";

#pragma mark /links
NSString* const MITMobileLinks = @"apis/links";

#pragma mark /maps
NSString* const MITMobileMapBootstrap = @"apis/map/bootstrap";
NSString* const MITMobileMapCategories = @"apis/map/place_categories";
NSString* const MITMobileMapPlaces = @"apis/map/places";
NSString* const MITMobileMapRooms = @"apis/map/rooms";
NSString* const MITMobileMapBuilding = @"apis/map/rooms/:building";

#pragma mark /news
NSString* const MITMobileNewsCategories = @"/news/categories";
NSString* const MITMobileNewsStories = @"/news/stories";

#pragma mark /people
NSString* const MITMobilePeople = @"/people";
NSString* const MITMobilePerson = @"/people/:id";

#pragma mark /shuttles
NSString* const MITMobileShuttlesRoutes = @"/shuttles/routes";
NSString* const MITMobileShuttlesRoute = @"/shuttles/routes/:route";
NSString* const MITMobileShuttlesStop = @"/shuttles/routes/:route/stops/:stop";

#pragma mark /techccash
NSString* const MITMobileTechcash = @"/techcash";
NSString* const MITMobileTechcashAccounts = @"/techcash/accounts";
NSString* const MITMobileTechcashAccount = @"/techcash/accounts/:id";

typedef void (^MITResourceLoadedBlock)(RKMappingResult *result, NSError *error);

#pragma mark - MITMobile
#pragma mark Private Extension
@interface MITMobile ()
@property (nonatomic,strong) NSMutableDictionary *objectManagers;
@property (nonatomic,strong) NSMutableDictionary *mutableResources;
@property (nonatomic,strong) RKManagedObjectStore *managedObjectStore;

- (RKObjectManager*)objectManagerForURL:(NSURL*)url;
@end

@implementation MITMobile
+ (MITMobile*)defaultManager
{
    return [[MIT_MobileAppDelegate applicationDelegate] remoteObjectManager];
}

- (instancetype)init;
{
    self = [super init];
    if (self) {
        _objectManagers = [[NSMutableDictionary alloc] init];
        _mutableResources = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)setManagedObjectStore:(RKManagedObjectStore *)managedObjectStore
{
    if (![self.managedObjectStore isEqual:managedObjectStore]) {
        _managedObjectStore = managedObjectStore;

        [self.objectManagers enumerateKeysAndObjectsUsingBlock:^(id key, RKObjectManager *objectManager, BOOL *stop) {
            [objectManager.operationQueue cancelAllOperations];
            objectManager.managedObjectStore = _managedObjectStore;
        }];
    }
}

- (void)setResource:(MITMobileResource*)resource forName:(NSString*)name
{
    NSParameterAssert(resource);
    NSAssert([resource isKindOfClass:[MITMobileResource class]], @"resource is not descended from MITMobileResource");
    NSAssert(!(self.mutableResources[name]), @"resource with name '%@' already exists",name);
    NSAssert([self.objectManagers count] == 0, @"resources can not be added after requests have been made");

    self.mutableResources[name] = resource;
}

- (MITMobileResource*)resourceForName:(NSString *)name
{
    return self.mutableResources[name];
}

- (NSDictionary*)resources
{
    return [self.mutableResources copy];
}

- (NSFetchRequest*)getObjectsForResourceNamed:(NSString *)routeName object:(id)object parameters:(NSDictionary *)parameters completion:(MITResourceLoadedBlock)block;
{
    // Trim off any additional paths. Right now, the API prefix (for the Mobile v3, '/apis')
    // is included in the route name but the current server URL uses '/api'.
    // Passing the current server URL directly into the routing subsystem confuses it.
    NSURL *serverURL = [[NSURL URLWithString:@"/"
                              relativeToURL:MITMobileWebGetCurrentServerURL()] absoluteURL];
    RKObjectManager *objectManager = [self objectManagerForURL:serverURL];
    
    NSString *uniquedRouteName = [NSString stringWithFormat:@"%@ %@",RKStringFromRequestMethod(RKRequestMethodGET),routeName];
    NSURL *url = [objectManager.router URLForRouteNamed:uniquedRouteName method:NULL object:nil];

    [objectManager getObjectsAtPathForRouteNamed:uniquedRouteName
                                               object:nil
                                           parameters:parameters
                                              success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                                  if (block) {
                                                      block(mappingResult,nil);
                                                  }
                                              }
                                              failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                                  if (block) {
                                                      block(nil,error);
                                                  }
                                              }];

    MITMobileResource *requestedResource = self.resources[routeName];
    return [requestedResource fetchRequestForURL:url];
}

- (RKObjectManager*)objectManagerForURL:(NSURL *)url
{
    RKObjectManager *objectManager = self.objectManagers[url];
    if (!objectManager) {
        objectManager = [RKObjectManager managerWithBaseURL:url];

        [self.resources enumerateKeysAndObjectsUsingBlock:^(NSString *name, MITMobileResource *resource, BOOL *stop) {
            NSIndexSet *successfulStatusCodes = RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful);
            
            // Setup the response descriptors for the resource. This will probably be done a different way
            // when (if) we move away from RKObjectManager.
            [resource enumerateMappingsByRequestMethodUsingBlock:^(RKRequestMethod method, NSDictionary *mappings) {
                [mappings enumerateKeysAndObjectsUsingBlock:^(NSString *keyPath, RKMapping *mapping, BOOL *stop) {
                    RKResponseDescriptor *responseDescriptor = [RKResponseDescriptor responseDescriptorWithMapping:mapping
                                                                                                            method:method
                                                                                                       pathPattern:resource.pathPattern
                                                                                                           keyPath:keyPath
                                                                                                       statusCodes:successfulStatusCodes];
                    [objectManager addResponseDescriptor:responseDescriptor];
                }];
                
                // And now register the route with the object manager's router. The request method is being
                // added here to unique the route name, otherwise, RKRouter will complain if there
                // are multiple routes with the same name (even if the method differs)
                RKRoute *route = [RKRoute routeWithName:[NSString stringWithFormat:@"%@ %@",RKStringFromRequestMethod(method),name]
                                            pathPattern:resource.pathPattern
                                                 method:method];
                
                [objectManager.router.routeSet addRoute:route];
            }];
            
            
            // Setup the fetch request generators so we can have nice things (like
            // killing orphans) for resources that provide the support
            __weak MITMobileResource *weakResource = resource;
            [objectManager addFetchRequestBlock:^(NSURL *URL) {
                return [weakResource fetchRequestForURL:URL];
            }];
        }];
        
        self.objectManagers[url] = objectManager;
    }

    if (!(objectManager.managedObjectStore || self.managedObjectStore)) {
        DDLogWarn(@"an RKManagedObjectStore has not been assigned; mappings requiring CoreData will not be performed");
    } else if (!objectManager.managedObjectStore) {
        objectManager.managedObjectStore = self.managedObjectStore;
    }


    return objectManager;
}

@end