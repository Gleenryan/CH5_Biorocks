#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "CoralystLogo" asset catalog image resource.
static NSString * const ACImageNameCoralystLogo AC_SWIFT_PRIVATE = @"CoralystLogo";

/// The "OnBoardingBackground" asset catalog image resource.
static NSString * const ACImageNameOnBoardingBackground AC_SWIFT_PRIVATE = @"OnBoardingBackground";

#undef AC_SWIFT_PRIVATE
