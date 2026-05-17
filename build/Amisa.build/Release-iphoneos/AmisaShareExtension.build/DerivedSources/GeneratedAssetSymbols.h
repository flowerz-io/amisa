#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"flowerz.io.Amisa.app.ShareExtension";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "provider_depop" asset catalog image resource.
static NSString * const ACImageNameProviderDepop AC_SWIFT_PRIVATE = @"provider_depop";

/// The "provider_ebay" asset catalog image resource.
static NSString * const ACImageNameProviderEbay AC_SWIFT_PRIVATE = @"provider_ebay";

/// The "provider_grailed" asset catalog image resource.
static NSString * const ACImageNameProviderGrailed AC_SWIFT_PRIVATE = @"provider_grailed";

/// The "provider_leboncoin" asset catalog image resource.
static NSString * const ACImageNameProviderLeboncoin AC_SWIFT_PRIVATE = @"provider_leboncoin";

/// The "provider_vinted" asset catalog image resource.
static NSString * const ACImageNameProviderVinted AC_SWIFT_PRIVATE = @"provider_vinted";

#undef AC_SWIFT_PRIVATE
