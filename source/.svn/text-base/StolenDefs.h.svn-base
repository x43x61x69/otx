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
typedef struct
{
    objc_class*     isa;
    char*           chars;
    unsigned int    length;
}
objc_string_object;

/*  CFString

    The only piece of reverse-engineered data in otx. I was unable to find any
    documentation about the structure of CFStrings, but they appear to be
    NSStrings with an extra data member prepended. Following NSString's lead,
    i'm calling it 'isa'. The observed values of 'isa' change from app to app,
    but remain constant in each app. A little gdb effort could probably shed
    some light on what they actually point to, but otx has nothing to gain from
    that knowledge. Still, any feedback regarding this issue is most welcome.
*/
typedef struct
{
    uint32_t              isa;
    objc_string_object  oc_string;
}
cf_string_object;

/*  The isa field of an NSString is 0x7c8 (1992) when it exists in the
    (__DATA,__const) section. This makes it possible to identify both
    NSString's and CFString's. I can't find any documentation about the
    1992 date, but it is assumed to be the date of birth of NSStrings.
*/
#define typeid_NSString     0x000007c8

/* ----------------------------------------------------------------------------
    Objective-C 2.0 private structs

    Copied and modified here because-
        The structs are private, unlike the earlier runtime.
        otx being 32-bit, the pointer fields need to be explicit about their size.

    For reference, the 'FOO' in 'typedef struct FOO' is the original private struct
    name, and the original pointer field types are saved as comments.
*/

typedef struct method_t
{
    uint64_t name;   // SEL
    uint64_t types;  // const char *
    uint64_t imp;    // IMP
}
objc2_method_t;

typedef struct method_list_t
{
    uint32_t entsize;
    uint32_t count;
    objc2_method_t first;
}
objc2_method_list_t;

typedef struct message_ref
{
    uint64_t imp;   // IMP
    uint64_t sel;   // SEL
}
objc2_message_ref_t;

typedef struct ivar_t
{
    // *offset is 64-bit by accident even though other 
    // fields restrict total instance size to 32-bit. 
    uint64_t offset;    // uintptr_t *
    uint64_t name;      // const char *
    uint64_t type;      // const char *
    uint32_t alignment;
    uint32_t size;
}
objc2_ivar_t;

typedef struct ivar_list_t
{
    uint32_t entsize;
    uint32_t count;
    objc2_ivar_t first;
}
objc2_ivar_list_t;

typedef struct protocol_t
{
    uint64_t isa;                       // id
    uint64_t name;                      // const char *
    uint64_t protocols;                 // struct objc2_protocol_list_t *
    uint64_t instanceMethods;           // objc2_method_list_t *
    uint64_t classMethods;              // objc2_method_list_t *
    uint64_t optionalInstanceMethods;   // objc2_method_list_t *
    uint64_t optionalClassMethods;      // objc2_method_list_t *
    uint64_t instanceProperties;        // struct objc2_property_list *
}
objc2_protocol_t;

typedef struct protocol_list_t
{
    // count is 64-bit by accident. 
    uint64_t count;     // uintptr_t
    uint64_t list[0];   // objc2_protocol_t *
}
objc2_protocol_list_t;

typedef struct class_ro_t
{
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
    uint32_t reserved;

    uint64_t ivarLayout;        // const uint8_t *

    uint64_t name;              // const char *
    uint64_t baseMethods;       // const objc2_method_list_t *
    uint64_t baseProtocols;     // const objc2_protocol_list_t *
    uint64_t ivars;             // const objc2_ivar_list_t *

    uint64_t weakIvarLayout;    // const uint8_t *
    uint64_t baseProperties;    // const struct objc2_property_list *
}
objc2_class_ro_t;

typedef struct class_rw_t
{
    uint32_t flags;
    uint32_t version;

    uint64_t ro;                // const objc2_class_ro_t *

    uint64_t methods;           // chained_method_list *
    uint64_t properties;        // chained_property_list *
    uint64_t protocols;         // objc2_protocol_list_t **

    uint64_t firstSubclass;     // objc2_class_t *
    uint64_t nextSiblingClass;  // objc2_class_t *
}
objc2_class_rw_t;

typedef struct class_t
{
    uint64_t isa;           // objc2_class_t *
    uint64_t superclass;    // objc2_class_t *
    uint64_t cache;         // Cache
    uint64_t vtable;        // IMP *
    uint64_t data;          // objc2_class_rw_t *
}
objc2_class_t;

typedef struct
{
    uint64_t    isa;
    uint64_t    chars;
    uint64_t    length;
}
objc2_string_object;

typedef struct
{
    uint64_t            isa;
    objc2_string_object oc_string;
}
cf_string_object_64;

// ----------------------------------------------------------------------------
//  Swap

//  swap_objc2_class
// ----------------------------------------------------------------------------

static void
swap_objc2_class(
    objc2_class_t* oc)
{
    oc->isa         = OSSwapInt64(oc->isa);
    oc->superclass  = OSSwapInt64(oc->superclass);
    oc->cache       = OSSwapInt64(oc->cache);
    oc->vtable      = OSSwapInt64(oc->vtable);
    oc->data        = OSSwapInt64(oc->data);
}

//  swap_objc2_method
// ----------------------------------------------------------------------------

static void
swap_objc2_method(
    objc2_method_t* m)
{
    m->name     = OSSwapInt64(m->name);
    m->types    = OSSwapInt64(m->types);
    m->imp      = OSSwapInt64(m->imp);
}

//  swap_objc2_ivar
// ----------------------------------------------------------------------------

static void
swap_objc2_ivar(
    objc2_ivar_t* i)
{
    i->offset       = OSSwapInt64(i->offset);
    i->name         = OSSwapInt64(i->name);
    i->type         = OSSwapInt64(i->type);
    i->alignment    = OSSwapInt32(i->alignment);
    i->size         = OSSwapInt32(i->size);
}
