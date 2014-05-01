/*
    ObjcTypes.h

    Definitions shared by GUI and CLI targets.

    This file is in the public domain.
*/


#import <Foundation/Foundation.h>

#pragma mark -
#pragma mark Shared (32-bit)

typedef struct {
    uint32_t isa;         /* Class  */
    uint32_t superclass;  /* Class  */
} *objc_32_class_ptr;


#pragma mark -
#pragma mark Objective-C 1.0 (32-bit)

typedef struct {
    uint32_t isa;            /* Class                           */
    uint32_t super_class;    /* Class                           */
    uint32_t name;           /* const char *                    */
    int32_t  version;        /* long                            */
    int32_t  info;           /* long                            */
    int32_t  instance_size;  /* long                            */
    uint32_t ivars;          /* struct objc_ivar_list *         */
    uint32_t methodLists;    /* struct objc_method_list **      */
    uint32_t cache;          /* struct objc_cache *             */
    uint32_t protocols;      /* struct objc_protocol_list *     */
} objc1_32_class;


typedef struct {
    uint32_t category_name;    /* char *                        */
    uint32_t class_name;       /* char *                        */
    uint32_t instance_methods; /* struct objc_method_list *     */
    uint32_t class_methods;    /* struct objc_method_list *     */
    uint32_t protocols;        /* struct objc_protocol_list *   */
} objc1_32_category;


typedef struct {
    uint32_t next;    /* struct objc_protocol_list *  */
    uint32_t count;   /* long                         */
    uint32_t list[1]; /* Protocol *                   */
} objc1_32_protocol_list;


typedef struct {
    uint32_t name;   /* const char *    */
    uint32_t value;  /* const char *    */
} objc1_32_property_attribute_t;


typedef struct {
    uint32_t ivar_name;    /* char * */
    uint32_t ivar_type;    /* char * */
    uint32_t ivar_offset;
} objc1_32_ivar;


typedef struct {
    int32_t ivar_count;         /* int                       */
    objc1_32_ivar ivar_list[1]; /* variable length structure */
} objc1_32_ivar_list;


typedef struct {
    uint32_t method_name;   /* SEL    */
    uint32_t method_types;  /* char * */
    uint32_t method_imp;    /* IMP    */
} objc1_32_method;


typedef struct {
    int32_t  obsolete;               /* struct objc_method_list *  */
    int32_t  method_count;           /* int                        */
    objc1_32_method method_list[1];  /* variable length structure  */
} objc1_32_method_list;


typedef struct {
    uint32_t  name;   /* SEL            */
    uint32_t *types;  /* char *         */
} objc1_32_method_description;


typedef struct {
    uint32_t version;     /* unsigned long      */
    uint32_t size;        /* unsigned long      */
    uint32_t name;        /* const char *       */
    uint32_t symtab;      /* objc_symtab *      */
} objc1_32_module;


typedef struct {
    uint32_t sel_ref_cnt;  /* unsigned long         */
    uint32_t refs;         /* SEL *                 */
    uint16_t cls_def_cnt;  /* unsigned short        */
    uint16_t cat_def_cnt;  /* unsigned short        */
    uint32_t defs[1];      /* void *, variable size */
} objc1_32_symtab;


typedef struct {
    uint32_t mask;       /* unsigned int, total = mask + 1 */
    uint32_t occupied;   /* unsigned int                   */
    uint32_t buckets[1]; /* Method                         */
} objc1_32_cache;


void swap_objc1_32_module(objc1_32_module *module);
void swap_objc1_32_symtab(objc1_32_symtab *symtab);
void swap_objc1_32_class(objc1_32_class *cls);
void swap_objc1_32_ivar(objc1_32_ivar *ivar);
void swap_objc1_32_category(objc1_32_category *category);
void swap_objc1_32_method_list(objc1_32_method_list *methodList);
void swap_objc1_32_method(objc1_32_method *method);


#pragma mark -
#pragma mark Objective-C 1.0 (64-bit)

typedef struct {
    uint64_t isa;            /* Class                           */
    uint64_t super_class;    /* Class                           */
    uint64_t name;           /* const char *                    */
    int64_t  version;        /* long                            */
    int64_t  info;           /* long                            */
    int64_t  instance_size;  /* long                            */
    uint64_t ivars;          /* struct objc_ivar_list *         */
    uint64_t methodLists;    /* struct objc_method_list **      */
    uint64_t cache;          /* struct objc_cache *             */
    uint64_t protocols;      /* struct objc_protocol_list *     */
} objc1_64_class;


typedef struct {
    uint64_t category_name;    /* char * */
    uint64_t class_name;       /* char * */
    uint64_t instance_methods; /* struct objc_method_list * */
    uint64_t class_methods;    /* struct objc_method_list * */
    uint64_t protocols;        /* struct objc_protocol_list * */
} objc1_64_category;


typedef struct {
    uint64_t next;    /* struct objc_protocol_list *  */
    uint64_t count;   /* long                         */
    uint64_t list[1]; /* Protocol *                   */
} objc1_64_protocol_list;


typedef struct {
    uint64_t name;   /* const char *    */
    uint64_t value;  /* const char *    */
} objc1_64_property_attribute_t;


typedef struct {
    uint64_t ivar_name;    /* char * */
    uint64_t ivar_type;    /* char * */
    uint64_t ivar_offset;
    uint32_t space;
} objc1_64_ivar;


typedef struct {
    int32_t ivar_count;         /* int                       */
    int32_t space;              /* int                       */
    objc1_64_ivar ivar_list[1]; /* variable length structure */
} objc1_64_ivar_list;


typedef struct {
    uint64_t method_name;   /* SEL    */
    uint64_t method_types;  /* char * */
    uint64_t method_imp;    /* IMP    */
} objc1_64_method;


typedef struct {                                                  
    int64_t  obsolete;               /* struct objc_method_list *  */
    int64_t  method_count;           /* int                        */
    int32_t  space;                  /* int                        */
    objc1_64_method method_list[1];  /* variable length structure  */
} objc1_64_method_list;


typedef struct {
    uint64_t  name;   /* SEL            */
    uint64_t *types;  /* char *         */
} objc1_64_method_description;


typedef struct {
    uint64_t version;  /* unsigned long      */
    uint64_t size;     /* unsigned long      */
    uint64_t name;     /* const char *       */
    uint64_t symtab;   /* objc_symtab *      */
} objc1_64_module;


typedef struct {
    uint64_t sel_ref_cnt;  /* unsigned long         */
    uint64_t refs;         /* SEL *                 */
    uint16_t cls_def_cnt;  /* unsigned short        */
    uint16_t cat_def_cnt;  /* unsigned short        */
    uint64_t defs[1];      /* void *, variable size */
} objc1_64_symtab;


typedef struct {
    uint32_t mask;       /* unsigned int, total = mask + 1 */
    uint32_t occupied;   /* unsigned int                   */
    uint64_t buckets[1]; /* Method                         */
} objc1_64_cache;


void swap_objc1_64_module(objc1_64_module *module);
void swap_objc1_64_symtab(objc1_64_symtab *symtab);
void swap_objc1_64_class(objc1_64_class *cls);
void swap_objc1_64_ivar(objc1_64_ivar *ivar);
void swap_objc1_64_category(objc1_64_category *category);
void swap_objc1_64_method_list(objc1_64_method_list *methodList);
void swap_objc1_64_method(objc1_64_method *method);


/* ----------------------------------------------------------------------------
    Objective-C 2.0 private structs

    Copied and modified here because-
        The structs are private, unlike the earlier runtime.
        otx being 32-bit, the pointer fields need to be explicit about their size.

    For reference, the 'FOO' in 'typedef struct FOO' is the original private struct
    name, and the original pointer field types are saved as comments.
*/


#pragma mark -
#pragma mark Objective-C 2.0 (32-bit)

typedef struct {
    uint32_t name;   // SEL
    uint32_t types;  // const char *
    uint32_t imp;    // IMP
} objc2_32_method_t;


typedef struct {
    uint32_t entsize;
    uint32_t count;
    objc2_32_method_t first;
} objc2_32_method_list_t;


typedef struct {
    uint32_t imp;   // IMP
    uint32_t sel;   // SEL
} objc2_32_message_ref_t;


typedef struct {
    // *offset is 64-bit by accident even though other 
    // fields restrict total instance size to 32-bit. 
    uint64_t offset;    // uintptr_t *
    uint32_t name;      // const char *
    uint32_t type;      // const char *
    uint32_t alignment;
    uint32_t size;
} objc2_32_ivar_t;


typedef struct {
    uint32_t entsize;
    uint32_t count;
    objc2_32_ivar_t first;
} objc2_32_ivar_list_t;


typedef struct {
    uint32_t isa;                       // id
    uint32_t name;                      // const char *
    uint32_t protocols;                 // struct objc2_protocol_list_t *
    uint32_t instanceMethods;           // objc2_method_list_t *
    uint32_t classMethods;              // objc2_method_list_t *
    uint32_t optionalInstanceMethods;   // objc2_method_list_t *
    uint32_t optionalClassMethods;      // objc2_method_list_t *
    uint32_t instanceProperties;        // struct objc2_property_list *
} objc2_32_protocol_t;


typedef struct {
    // count is 64-bit by accident. 
    uint64_t count;     // uintptr_t
    uint32_t list[0];   // objc2_protocol_t *
} objc2_32_protocol_list_t;


typedef struct {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;

    uint32_t ivarLayout;        // const uint8_t *

    uint32_t name;              // const char *
    uint32_t baseMethods;       // const objc2_method_list_t *
    uint32_t baseProtocols;     // const objc2_protocol_list_t *
    uint32_t ivars;             // const objc2_ivar_list_t *

    uint32_t weakIvarLayout;    // const uint8_t *
    uint32_t baseProperties;    // const struct objc2_property_list *
} objc2_32_class_ro_t;


typedef struct {
    uint32_t flags;
    uint32_t version;

    uint32_t ro;                // const objc2_class_ro_t *

    uint32_t methods;           // chained_method_list *
    uint32_t properties;        // chained_property_list *
    uint32_t protocols;         // objc2_protocol_list_t **

    uint32_t firstSubclass;     // objc2_class_t *
    uint32_t nextSiblingClass;  // objc2_class_t *
} objc2_32_class_rw_t;


typedef struct {
    uint32_t isa;           // objc2_class_t *
    uint32_t superclass;    // objc2_class_t *
    uint32_t cache;         // Cache
    uint32_t vtable;        // IMP *
    uint32_t data;          // objc2_class_rw_t *
} objc2_32_class_t;


extern void swap_objc2_32_class(objc2_32_class_t *cls);
extern void swap_objc2_32_method(objc2_32_method_t *method);
extern void swap_objc2_32_ivar(objc2_32_ivar_t* ivar);


#pragma mark -
#pragma mark Objective-C 2.0 (64-bit)

typedef struct {
    uint64_t name;   // SEL
    uint64_t types;  // const char *
    uint64_t imp;    // IMP
} objc2_64_method_t;


typedef struct {
    uint32_t entsize;
    uint32_t count;
    objc2_64_method_t first;
} objc2_64_method_list_t;


typedef struct {
    uint64_t imp;   // IMP
    uint64_t sel;   // SEL
} objc2_64_message_ref_t;


typedef struct {
    // *offset is 64-bit by accident even though other 
    // fields restrict total instance size to 32-bit. 
    uint64_t offset;    // uintptr_t *
    uint64_t name;      // const char *
    uint64_t type;      // const char *
    uint32_t alignment;
    uint32_t size;
} objc2_64_ivar_t;


typedef struct {
    uint32_t entsize;
    uint32_t count;
    objc2_64_ivar_t first;
} objc2_64_ivar_list_t;


typedef struct {
    uint64_t isa;                       // id
    uint64_t name;                      // const char *
    uint64_t protocols;                 // struct objc2_protocol_list_t *
    uint64_t instanceMethods;           // objc2_method_list_t *
    uint64_t classMethods;              // objc2_method_list_t *
    uint64_t optionalInstanceMethods;   // objc2_method_list_t *
    uint64_t optionalClassMethods;      // objc2_method_list_t *
    uint64_t instanceProperties;        // struct objc2_property_list *
} objc2_64_protocol_t;


typedef struct {
    uint64_t count;     // uintptr_t - count is 64-bit by accident. 
    uint64_t list[0];   // objc2_protocol_t *
} objc2_64_protocol_list_t;


typedef struct {
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
} objc2_64_class_ro_t;


typedef struct {
    uint32_t flags;
    uint32_t version;

    uint64_t ro;                // const objc2_class_ro_t *

    uint64_t methods;           // chained_method_list *
    uint64_t properties;        // chained_property_list *
    uint64_t protocols;         // objc2_protocol_list_t **

    uint64_t firstSubclass;     // objc2_class_t *
    uint64_t nextSiblingClass;  // objc2_class_t *
} objc2_64_class_rw_t;


typedef struct {
    uint64_t isa;           // objc2_class_t *
    uint64_t superclass;    // objc2_class_t *
    uint64_t cache;         // Cache
    uint64_t vtable;        // IMP *
    uint64_t data;          // objc2_class_rw_t *
} objc2_64_class_t;

extern void swap_objc2_64_class(objc2_64_class_t *cls);
extern void swap_objc2_64_method(objc2_64_method_t *method);
extern void swap_objc2_64_ivar(objc2_64_ivar_t *ivar);

