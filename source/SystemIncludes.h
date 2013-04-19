/*
    SystemIncludes.h

    In order to implement the struct shortcut, all system files that define
    structs need to be #included before the #defines. To make this easier,
    all such files are included from here, and other files simply include
    this file. The behavior of the #import directive makes this safe.

    This file is in the public domain.
*/

#ifdef __OBJC__
    #import <Cocoa/Cocoa.h>
#endif

#import <libkern/OSByteOrder.h>
#import <mach/machine.h>
#import <mach-o/arch.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <mach-o/swap.h>
#import <objc/objc-runtime.h>
#import <sys/param.h>
#import <sys/ptrace.h>
#import <sys/syscall.h>
#import <sys/types.h>

#define fat_header          struct fat_header
#define fat_arch            struct fat_arch
#define mach_header         struct mach_header
#define mach_header_64      struct mach_header_64
#define load_command        struct load_command
#define segment_command     struct segment_command
#define segment_command_64  struct segment_command_64
#define symtab_command      struct symtab_command
#define dysymtab_command    struct dysymtab_command
#define nlist               struct nlist
#define nlist_64            struct nlist_64
#define section             struct section
#define section_64          struct section_64
#define objc_module         struct objc_module
#define objc_symtab         struct objc_symtab
#define objc_class          struct objc_class
#define objc_ivar_list      struct objc_ivar_list
#define objc_ivar           struct objc_ivar
#define objc_method_list    struct objc_method_list
#define objc_method         struct objc_method
#define objc_cache          struct objc_cache
#define objc_category       struct objc_category
#define objc_protocol_list  struct objc_protocol_list

// carpal tunnel inhibitors
#define UTF8STRING(s)   [(s) UTF8String]
#define NSSTRING(s)     [NSString stringWithUTF8String: (s)]
