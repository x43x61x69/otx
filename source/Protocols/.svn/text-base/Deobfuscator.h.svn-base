/*
    Deobfuscator.h

    This file is in the public domain.
*/

#import <Cocoa/Cocoa.h>

/*  NopList

    'list' is a 'count'-sized array of addresses at which an obfuscated
    sequence of nops was found.
*/
typedef struct NopList
{
    unsigned char** list;
    uint32_t          count;
}
NopList;

// ============================================================================

@protocol Deobfuscator

- (BOOL)verifyNops: (unsigned char***)outList
          numFound: (uint32_t*)outFound;
- (unsigned char**)searchForNopsIn: (unsigned char*)inHaystack
                          ofLength: (uint32_t)inHaystackLength
                          numFound: (uint32_t*)outFound;
- (NSURL*)fixNops: (NopList*)inList
           toPath: (NSString*)inOutputFilePath;

@end
