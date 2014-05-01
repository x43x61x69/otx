/*
    StolenDefs.h

    Definitions stolen from, or inspired by, Darwin & cctools.

    This file is in the public domain.
*/

#define rotr(x, n)   (((x) >> ((int)(n))) | ((x) << (32 - (int)(n))))
#define rotl(x, n)   (((x) << ((int)(n))) | ((x) >> (32 - (int)(n))))
#define rotr64(x, n) (((x) >> ((int)(n))) | ((x) << (64 - (int)(n))))
#define rotl64(x, n) (((x) << ((int)(n))) | ((x) >> (64 - (int)(n))))

/*  section_info
*/
typedef struct
{
    section         s;
    char*           contents;
    uint32_t        size;
}
section_info;

typedef struct
{
    section_64      s;
    char*           contents;
    uint64_t        size;
}
section_info_64;

/*  dyld_data_section

    Adapted from
    http://www.opensource.apple.com/darwinsource/10.4.7.ppc/cctools-590.23.6/libdyld/debug.h
*/
typedef struct
{
    void*           stub_binding_helper_interface;
    void*           _dyld_func_lookup;
    void*           start_debug_thread;
    mach_port_t     debug_port;
    thread_port_t   debug_thread;
    void*           dyld_stub_binding_helper;
//  unsigned long   core_debug; // wrong size and ignored by us anyway
}
dyld_data_section;



/*  NSString

    From cctools-590/otool/print_objc.c, alternate definition in
    http://www.opensource.apple.com/darwinsource/10.4.7.ppc/objc4-267.1/runtime/objc-private.h
*/
typedef struct {
    uint32_t  isa;    /* objc_class *       */
    uint32_t  chars;  /* char *             */
    uint32_t  length; /* unsigned int       */
} nxstring_object;

typedef struct {
    uint64_t isa;     /* objc_class *       */
    uint64_t chars;   /* char *             */ 
    uint32_t length;  /* unsigned int       */
} nxstring_object_64;


/*  CFString

    The only piece of reverse-engineered data in otx. I was unable to find any
    documentation about the structure of CFStrings, but they appear to be
    NSStrings with an extra data member prepended. Following NSString's lead,
    i'm calling it 'isa'. The observed values of 'isa' change from app to app,
    but remain constant in each app. A little gdb effort could probably shed
    some light on what they actually point to, but otx has nothing to gain from
    that knowledge. Still, any feedback regarding this issue is most welcome.
*/
typedef struct {
    uint32_t isa;
    nxstring_object oc_string;
} cfstring_object;

typedef struct {
    uint64_t isa;
    nxstring_object_64 oc_string;
} cfstring_object_64;




/*  The isa field of an NSString is 0x7c8 (1992) when it exists in the
    (__DATA,__const) section. This makes it possible to identify both
    NSString's and CFString's. I can't find any documentation about the
    1992 date, but it is assumed to be the date of birth of NSStrings.
*/
#define typeid_NSString     0x000007c8
