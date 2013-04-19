/*
    ObjcSwap.c

    Functions adapted from cctools-590/otool/print_objc.c

    This file is in the public domain.
*/

#import "SystemIncludes.h"
//#import "StolenDefs.h"

//  swap_objc_module
// ----------------------------------------------------------------------------

void
swap_objc_module(
    objc_module* module)
{
    module->version = OSSwapInt32(module->version);
    module->size    = OSSwapInt32(module->size);
    module->name    = (char*)OSSwapInt32((int32_t)module->name);
    module->symtab  = (Symtab)OSSwapInt32((int32_t)module->symtab);
}

//  swap_objc_symtab
// ----------------------------------------------------------------------------

void
swap_objc_symtab(
    objc_symtab* symtab)
{
    symtab->sel_ref_cnt = OSSwapInt32(symtab->sel_ref_cnt);
    symtab->refs        = (SEL*)OSSwapInt32((int32_t)symtab->refs);
    symtab->cls_def_cnt = OSSwapInt16(symtab->cls_def_cnt);
    symtab->cat_def_cnt = OSSwapInt16(symtab->cat_def_cnt);
}

//  swap_objc_class
// ----------------------------------------------------------------------------

void
swap_objc_class(
    objc_class* oc)
{
    oc->isa             = (objc_class*)OSSwapInt32((long)oc->isa);
    oc->super_class     = (objc_class*)OSSwapInt32((long)oc->super_class);
    oc->name            = (const char*)OSSwapInt32((long)oc->name);     
    oc->version         = OSSwapInt32(oc->version);
    oc->info            = OSSwapInt32(oc->info);
    oc->instance_size   = OSSwapInt32(oc->instance_size);
    oc->ivars           = (objc_ivar_list*)OSSwapInt32((long)oc->ivars);
    oc->methodLists     =
        (objc_method_list**)OSSwapInt32((long)oc->methodLists);
    oc->cache           = (objc_cache*)OSSwapInt32((long)oc->cache);
    oc->protocols       =
        (objc_protocol_list*)OSSwapInt32((long)oc->protocols);
}

//  swap_objc_ivar
// ----------------------------------------------------------------------------

void
swap_objc_ivar(
    objc_ivar* oi)
{
    oi->ivar_name   = (char*)OSSwapInt32((long)oi->ivar_name);
    oi->ivar_type   = (char*)OSSwapInt32((long)oi->ivar_type);
    oi->ivar_offset = OSSwapInt32(oi->ivar_offset);
}

//  swap_objc_category
// ----------------------------------------------------------------------------

void
swap_objc_category(
    objc_category* oc)
{
    oc->category_name       = (char*)OSSwapInt32((long)oc->category_name);
    oc->class_name          = (char*)OSSwapInt32((long)oc->class_name);
    oc->instance_methods    =
        (objc_method_list*)OSSwapInt32((long)oc->instance_methods);
    oc->class_methods       =
        (objc_method_list*)OSSwapInt32((long)oc->class_methods);
    oc->protocols           =
        (objc_protocol_list*)OSSwapInt32((long)oc->protocols);
}

//  swap_objc_method_list
// ----------------------------------------------------------------------------

void
swap_objc_method_list(
    objc_method_list* ml)
{
    ml->obsolete        = (objc_method_list*)OSSwapInt32((long)ml->obsolete);
    ml->method_count    = OSSwapInt32(ml->method_count);
}

//  swap_objc_method
// ----------------------------------------------------------------------------

void
swap_objc_method(
    objc_method* m)
{
    m->method_name     = (SEL)OSSwapInt32((long)m->method_name);
    m->method_types    = (char*)OSSwapInt32((long)m->method_types);
    m->method_imp      = (IMP)OSSwapInt32((long)m->method_imp);
}

