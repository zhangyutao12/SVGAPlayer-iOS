//
//  SVGAVideoMemoryCache.m
//  SVGAPlayer
//

#import "SVGAVideoMemoryCache.h"
#import "SVGAVideoEntity.h"
#import <UIKit/UIKit.h>

@interface SVGAVideoMemoryCacheEntry : NSObject
@property (nonatomic, copy) id<NSCopying> key;
@property (nonatomic, strong) SVGAVideoEntity *videoEntity;
@end

@implementation SVGAVideoMemoryCacheEntry
@end

@interface SVGAVideoMemoryCache () <NSCacheDelegate>
@property (nonatomic, strong) NSCache *strongCache;
@property (nonatomic, strong) NSMapTable *weakCache;
@property (nonatomic, strong) NSMutableDictionary<id<NSCopying>, SVGAVideoMemoryCacheEntry *> *strongEntries;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, readwrite) NSUInteger totalMemoryCost;
@end

@implementation SVGAVideoMemoryCache

+ (instancetype)sharedCache {
    static SVGAVideoMemoryCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[self alloc] init];
    });
    return cache;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _strongCache = [[NSCache alloc] init];
        _strongCache.delegate = self;
        _weakCache = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory
                                               valueOptions:NSPointerFunctionsWeakMemory
                                                   capacity:128];
        _strongEntries = [[NSMutableDictionary alloc] init];
        _lock = dispatch_semaphore_create(1);
        _memoryCacheEnable = YES;
        _clearInBackground = YES;
        self.memoryCostLimit = 50 * 1024 * 1024;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setMemoryCostLimit:(NSUInteger)memoryCostLimit {
    _memoryCostLimit = memoryCostLimit;
    self.strongCache.totalCostLimit = memoryCostLimit;
}

- (void)setVideoEntity:(SVGAVideoEntity *)videoEntity
                forKey:(id<NSCopying>)key
        useStrongCache:(BOOL)useStrongCache {
    if (videoEntity == nil || key == nil) {
        return;
    }

    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.weakCache setObject:videoEntity forKey:key];
    dispatch_semaphore_signal(self.lock);

    if (!useStrongCache || !self.memoryCacheEnable) {
        return;
    }

    SVGAVideoMemoryCacheEntry *entry = [[SVGAVideoMemoryCacheEntry alloc] init];
    entry.key = key;
    entry.videoEntity = videoEntity;
    NSUInteger cost = videoEntity.memoryCost;

    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    SVGAVideoMemoryCacheEntry *previousEntry = self.strongEntries[key];
    if (previousEntry != nil) {
        self.totalMemoryCost -= MIN(self.totalMemoryCost, previousEntry.videoEntity.memoryCost);
    }
    self.strongEntries[key] = entry;
    self.totalMemoryCost += cost;
    dispatch_semaphore_signal(self.lock);

    [self.strongCache setObject:entry forKey:key cost:cost];
}

- (SVGAVideoEntity *)videoEntityForKey:(id<NSCopying>)key {
    if (key == nil) {
        return nil;
    }

    SVGAVideoMemoryCacheEntry *entry = [self.strongCache objectForKey:key];
    if (entry != nil) {
        return entry.videoEntity;
    }

    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    SVGAVideoEntity *videoEntity = [self.weakCache objectForKey:key];
    dispatch_semaphore_signal(self.lock);
    return videoEntity;
}

- (void)removeVideoEntityForKey:(id<NSCopying>)key {
    if (key == nil) {
        return;
    }

    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    SVGAVideoMemoryCacheEntry *entry = self.strongEntries[key];
    if (entry != nil) {
        self.totalMemoryCost -= MIN(self.totalMemoryCost, entry.videoEntity.memoryCost);
        [self.strongEntries removeObjectForKey:key];
    }
    [self.weakCache removeObjectForKey:key];
    dispatch_semaphore_signal(self.lock);
    [self.strongCache removeObjectForKey:key];
}

- (void)removeAllObjects {
    [self.strongCache removeAllObjects];
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    [self.strongEntries removeAllObjects];
    [self.weakCache removeAllObjects];
    self.totalMemoryCost = 0;
    dispatch_semaphore_signal(self.lock);
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (self.clearInBackground) {
        [self removeAllObjects];
    }
}

- (void)cache:(NSCache *)cache willEvictObject:(id)object {
    if (![object isKindOfClass:[SVGAVideoMemoryCacheEntry class]]) {
        return;
    }
    SVGAVideoMemoryCacheEntry *entry = object;
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    if (self.strongEntries[entry.key] == entry) {
        self.totalMemoryCost -= MIN(self.totalMemoryCost, entry.videoEntity.memoryCost);
        [self.strongEntries removeObjectForKey:entry.key];
    }
    dispatch_semaphore_signal(self.lock);
}

@end
