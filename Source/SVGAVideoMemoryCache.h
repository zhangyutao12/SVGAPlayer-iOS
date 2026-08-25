//
//  SVGAVideoMemoryCache.h
//  SVGAPlayer
//

#import <Foundation/Foundation.h>

@class SVGAVideoEntity;

NS_ASSUME_NONNULL_BEGIN

/// Thread-safe in-memory cache for parsed SVGA video entities.
@interface SVGAVideoMemoryCache : NSObject

/// Strong-cache memory limit in bytes. The default is 50 MB.
@property (nonatomic, assign) NSUInteger memoryCostLimit;
/// Whether entries saved through `saveCache:` use a strong cache. Defaults to YES.
@property (nonatomic, assign) BOOL memoryCacheEnable;
/// Whether the strong cache is cleared when the app enters the background. Defaults to YES.
@property (nonatomic, assign) BOOL clearInBackground;
/// Approximate memory cost of the current strong-cache entries, in bytes.
@property (nonatomic, readonly) NSUInteger totalMemoryCost;

+ (instancetype)sharedCache;

- (void)setVideoEntity:(SVGAVideoEntity *)videoEntity
                forKey:(id<NSCopying>)key
        useStrongCache:(BOOL)useStrongCache;
- (nullable SVGAVideoEntity *)videoEntityForKey:(id<NSCopying>)key;
- (void)removeVideoEntityForKey:(id<NSCopying>)key;
- (void)removeAllObjects;

@end

NS_ASSUME_NONNULL_END
