/*
    ObjcTypes.m

    Definitions shared by GUI and CLI targets.

    This file is in the public domain.
*/


#import "ObjcTypes.h"


void swap_objc1_32_module(objc1_32_module *m)
{
    m->version = OSSwapInt32(m->version);
    m->size    = OSSwapInt32(m->size);
    m->name    = OSSwapInt32(m->name);
    m->symtab  = OSSwapInt32(m->symtab);
}


void swap_objc1_32_symtab(objc1_32_symtab *s)
{
    s->sel_ref_cnt = OSSwapInt32(s->sel_ref_cnt);
    s->refs        = OSSwapInt32(s->refs);
    s->cls_def_cnt = OSSwapInt16(s->cls_def_cnt);
    s->cat_def_cnt = OSSwapInt16(s->cat_def_cnt);
}


void swap_objc1_32_class(objc1_32_class *c)
{
    c->isa             = OSSwapInt32(c->isa);
    c->super_class     = OSSwapInt32(c->super_class);
    c->name            = OSSwapInt32(c->name);     
    c->version         = OSSwapInt32(c->version);
    c->info            = OSSwapInt32(c->info);
    c->instance_size   = OSSwapInt32(c->instance_size);
    c->ivars           = OSSwapInt32(c->ivars);
    c->methodLists     = OSSwapInt32(c->methodLists);
    c->cache           = OSSwapInt32(c->cache);
    c->protocols       = OSSwapInt32(c->protocols);
}


void swap_objc1_32_ivar(objc1_32_ivar *i)
{
    i->ivar_name   = OSSwapInt32(i->ivar_name);
    i->ivar_type   = OSSwapInt32(i->ivar_type);
    i->ivar_offset = OSSwapInt32(i->ivar_offset);
}


void swap_objc1_32_category(objc1_32_category *c)
{
    c->category_name    = OSSwapInt32(c->category_name);
    c->class_name       = OSSwapInt32(c->class_name);
    c->instance_methods = OSSwapInt32(c->instance_methods);
    c->class_methods    = OSSwapInt32(c->class_methods);
    c->protocols        = OSSwapInt32(c->protocols);
}


void swap_objc1_32_method_list(objc1_32_method_list *m)
{
    m->obsolete     = OSSwapInt32(m->obsolete);
    m->method_count = OSSwapInt32(m->method_count);
}


void swap_objc1_32_method(objc1_32_method *m)
{
    m->method_name  = OSSwapInt32(m->method_name);
    m->method_types = OSSwapInt32(m->method_types);
    m->method_imp   = OSSwapInt32(m->method_imp);
}


void swap_objc1_64_module(objc1_64_module *m)
{
    m->version = OSSwapInt64(m->version);
    m->size    = OSSwapInt64(m->size);
    m->name    = OSSwapInt64(m->name);
    m->symtab  = OSSwapInt64(m->symtab);
}


void swap_objc1_64_symtab(objc1_64_symtab *s)
{
    s->sel_ref_cnt = OSSwapInt64(s->sel_ref_cnt);
    s->refs        = OSSwapInt64(s->refs);
    s->cls_def_cnt = OSSwapInt16(s->cls_def_cnt);
    s->cat_def_cnt = OSSwapInt16(s->cat_def_cnt);
}


void swap_objc1_64_class(objc1_64_class *c)
{
    c->isa             = OSSwapInt64(c->isa);
    c->super_class     = OSSwapInt64(c->super_class);
    c->name            = OSSwapInt64(c->name);     
    c->version         = OSSwapInt64(c->version);
    c->info            = OSSwapInt64(c->info);
    c->instance_size   = OSSwapInt64(c->instance_size);
    c->ivars           = OSSwapInt64(c->ivars);
    c->methodLists     = OSSwapInt64(c->methodLists);
    c->cache           = OSSwapInt64(c->cache);
    c->protocols       = OSSwapInt64(c->protocols);
}


void swap_objc1_64_ivar(objc1_64_ivar *i)
{
    i->ivar_name   = OSSwapInt64(i->ivar_name);
    i->ivar_type   = OSSwapInt64(i->ivar_type);
    i->ivar_offset = OSSwapInt64(i->ivar_offset);
}


void swap_objc1_64_category(objc1_64_category *c)
{
    c->category_name    = OSSwapInt64(c->category_name);
    c->class_name       = OSSwapInt64(c->class_name);
    c->instance_methods = OSSwapInt64(c->instance_methods);
    c->class_methods    = OSSwapInt64(c->class_methods);
    c->protocols        = OSSwapInt64(c->protocols);
}


void swap_objc1_64_method_list(objc1_64_method_list *m)
{
    m->obsolete     = OSSwapInt64(m->obsolete);
    m->method_count = OSSwapInt64(m->method_count);
}


void swap_objc1_64_method(objc1_64_method *m)
{
    m->method_name  = OSSwapInt64(m->method_name);
    m->method_types = OSSwapInt64(m->method_types);
    m->method_imp   = OSSwapInt64(m->method_imp);
}


void swap_objc2_32_class(objc2_32_class_t *c)
{
    c->isa        = OSSwapInt32(c->isa);
    c->superclass = OSSwapInt32(c->superclass);
    c->cache      = OSSwapInt32(c->cache);
    c->vtable     = OSSwapInt32(c->vtable);
    c->data       = OSSwapInt32(c->data);
}


void swap_objc2_32_method(objc2_32_method_t *m)
{
    m->name       = OSSwapInt32(m->name);
    m->types      = OSSwapInt32(m->types);
    m->imp        = OSSwapInt32(m->imp);
}


void swap_objc2_32_ivar(objc2_32_ivar_t *i)
{
    i->offset     = OSSwapInt64(i->offset);
    i->name       = OSSwapInt32(i->name);
    i->type       = OSSwapInt32(i->type);
    i->alignment  = OSSwapInt32(i->alignment);
    i->size       = OSSwapInt32(i->size);
}


void swap_objc2_64_class(objc2_64_class_t *c)
{
    c->isa        = OSSwapInt64(c->isa);
    c->superclass = OSSwapInt64(c->superclass);
    c->cache      = OSSwapInt64(c->cache);
    c->vtable     = OSSwapInt64(c->vtable);
    c->data       = OSSwapInt64(c->data);
}


void swap_objc2_64_method(objc2_64_method_t *m)
{
    m->name      = OSSwapInt64(m->name);
    m->types     = OSSwapInt64(m->types);
    m->imp       = OSSwapInt64(m->imp);
}


void swap_objc2_64_ivar(objc2_64_ivar_t *i)
{
    i->offset    = OSSwapInt64(i->offset);
    i->name      = OSSwapInt64(i->name);
    i->type      = OSSwapInt64(i->type);
    i->alignment = OSSwapInt32(i->alignment);
    i->size      = OSSwapInt32(i->size);
}

