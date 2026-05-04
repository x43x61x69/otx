/*
    MachOSwap.h

    Inline replacements for the deprecated swap_* functions from <mach-o/swap.h>.
    Those functions were deprecated in macOS 10.12; their behavior (unconditionally
    byte-swap every field of the given struct) is reproduced here using OSSwapInt32/64.

    SystemIncludes.h defines #define aliases such as "mach_header → struct mach_header",
    so this header uses those alias names throughout (no bare "struct" keyword).

    Include this header AFTER SystemIncludes.h.  The #defines at the bottom redirect
    every call-site to our non-deprecated versions; no call-site needs to change.

    This file is in the public domain.
*/

#pragma once

#include <stdint.h>
#include <libkern/OSByteOrder.h>

// ---------------------------------------------------------------------------
// Inline implementations
// (Types use the SystemIncludes.h aliases, e.g. mach_header == struct mach_header)
// ---------------------------------------------------------------------------

static inline void otx_swap_mach_header(mach_header *mh)
{
    mh->magic      = OSSwapInt32(mh->magic);
    mh->cputype    = OSSwapInt32(mh->cputype);
    mh->cpusubtype = OSSwapInt32(mh->cpusubtype);
    mh->filetype   = OSSwapInt32(mh->filetype);
    mh->ncmds      = OSSwapInt32(mh->ncmds);
    mh->sizeofcmds = OSSwapInt32(mh->sizeofcmds);
    mh->flags      = OSSwapInt32(mh->flags);
}

static inline void otx_swap_mach_header_64(mach_header_64 *mh)
{
    mh->magic      = OSSwapInt32(mh->magic);
    mh->cputype    = OSSwapInt32(mh->cputype);
    mh->cpusubtype = OSSwapInt32(mh->cpusubtype);
    mh->filetype   = OSSwapInt32(mh->filetype);
    mh->ncmds      = OSSwapInt32(mh->ncmds);
    mh->sizeofcmds = OSSwapInt32(mh->sizeofcmds);
    mh->flags      = OSSwapInt32(mh->flags);
    mh->reserved   = OSSwapInt32(mh->reserved);
}

static inline void otx_swap_fat_header(fat_header *fh)
{
    fh->magic     = OSSwapInt32(fh->magic);
    fh->nfat_arch = OSSwapInt32(fh->nfat_arch);
}

static inline void otx_swap_fat_arch(fat_arch *fa, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        fa[i].cputype    = OSSwapInt32(fa[i].cputype);
        fa[i].cpusubtype = OSSwapInt32(fa[i].cpusubtype);
        fa[i].offset     = OSSwapInt32(fa[i].offset);
        fa[i].size       = OSSwapInt32(fa[i].size);
        fa[i].align      = OSSwapInt32(fa[i].align);
    }
}

static inline void otx_swap_segment_command(segment_command *sg)
{
    sg->cmd      = OSSwapInt32(sg->cmd);
    sg->cmdsize  = OSSwapInt32(sg->cmdsize);
    sg->vmaddr   = OSSwapInt32(sg->vmaddr);
    sg->vmsize   = OSSwapInt32(sg->vmsize);
    sg->fileoff  = OSSwapInt32(sg->fileoff);
    sg->filesize = OSSwapInt32(sg->filesize);
    sg->maxprot  = OSSwapInt32(sg->maxprot);
    sg->initprot = OSSwapInt32(sg->initprot);
    sg->nsects   = OSSwapInt32(sg->nsects);
    sg->flags    = OSSwapInt32(sg->flags);
}

static inline void otx_swap_segment_command_64(segment_command_64 *sg)
{
    sg->cmd      = OSSwapInt32(sg->cmd);
    sg->cmdsize  = OSSwapInt32(sg->cmdsize);
    sg->vmaddr   = OSSwapInt64(sg->vmaddr);
    sg->vmsize   = OSSwapInt64(sg->vmsize);
    sg->fileoff  = OSSwapInt64(sg->fileoff);
    sg->filesize = OSSwapInt64(sg->filesize);
    sg->maxprot  = OSSwapInt32(sg->maxprot);
    sg->initprot = OSSwapInt32(sg->initprot);
    sg->nsects   = OSSwapInt32(sg->nsects);
    sg->flags    = OSSwapInt32(sg->flags);
}

static inline void otx_swap_section(section *s, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        s[i].addr      = OSSwapInt32(s[i].addr);
        s[i].size      = OSSwapInt32(s[i].size);
        s[i].offset    = OSSwapInt32(s[i].offset);
        s[i].align     = OSSwapInt32(s[i].align);
        s[i].reloff    = OSSwapInt32(s[i].reloff);
        s[i].nreloc    = OSSwapInt32(s[i].nreloc);
        s[i].flags     = OSSwapInt32(s[i].flags);
        s[i].reserved1 = OSSwapInt32(s[i].reserved1);
        s[i].reserved2 = OSSwapInt32(s[i].reserved2);
    }
}

static inline void otx_swap_section_64(section_64 *s, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        s[i].addr      = OSSwapInt64(s[i].addr);
        s[i].size      = OSSwapInt64(s[i].size);
        s[i].offset    = OSSwapInt32(s[i].offset);
        s[i].align     = OSSwapInt32(s[i].align);
        s[i].reloff    = OSSwapInt32(s[i].reloff);
        s[i].nreloc    = OSSwapInt32(s[i].nreloc);
        s[i].flags     = OSSwapInt32(s[i].flags);
        s[i].reserved1 = OSSwapInt32(s[i].reserved1);
        s[i].reserved2 = OSSwapInt32(s[i].reserved2);
        s[i].reserved3 = OSSwapInt32(s[i].reserved3);
    }
}

static inline void otx_swap_load_command(load_command *lc)
{
    lc->cmd     = OSSwapInt32(lc->cmd);
    lc->cmdsize = OSSwapInt32(lc->cmdsize);
}

static inline void otx_swap_symtab_command(symtab_command *st)
{
    st->cmd     = OSSwapInt32(st->cmd);
    st->cmdsize = OSSwapInt32(st->cmdsize);
    st->symoff  = OSSwapInt32(st->symoff);
    st->nsyms   = OSSwapInt32(st->nsyms);
    st->stroff  = OSSwapInt32(st->stroff);
    st->strsize = OSSwapInt32(st->strsize);
}

static inline void otx_swap_nlist(nlist *nl, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        nl[i].n_un.n_strx = OSSwapInt32(nl[i].n_un.n_strx);
        // n_type and n_sect are uint8_t — no swap needed
        nl[i].n_desc  = (int16_t)OSSwapInt16((uint16_t)nl[i].n_desc);
        nl[i].n_value = OSSwapInt32(nl[i].n_value);
    }
}

static inline void otx_swap_nlist_64(nlist_64 *nl, uint32_t n)
{
    for (uint32_t i = 0; i < n; i++) {
        nl[i].n_un.n_strx = OSSwapInt32(nl[i].n_un.n_strx);
        // n_type and n_sect are uint8_t — no swap needed
        nl[i].n_desc  = OSSwapInt16(nl[i].n_desc);
        nl[i].n_value = OSSwapInt64(nl[i].n_value);
    }
}

// ---------------------------------------------------------------------------
// Redirect the deprecated names — call sites need no changes.
// The variadic tail captures (and discards) the NXByteOrder argument.
// ---------------------------------------------------------------------------

#define swap_mach_header(mh, ...)          otx_swap_mach_header(mh)
#define swap_mach_header_64(mh, ...)       otx_swap_mach_header_64(mh)
#define swap_fat_header(fh, ...)           otx_swap_fat_header(fh)
#define swap_fat_arch(fa, n, ...)          otx_swap_fat_arch(fa, n)
#define swap_segment_command(sg, ...)      otx_swap_segment_command(sg)
#define swap_segment_command_64(sg, ...)   otx_swap_segment_command_64(sg)
#define swap_section(s, n, ...)            otx_swap_section(s, n)
#define swap_section_64(s, n, ...)         otx_swap_section_64(s, n)
#define swap_load_command(lc, ...)         otx_swap_load_command(lc)
#define swap_symtab_command(st, ...)       otx_swap_symtab_command(st)
#define swap_nlist(nl, n, ...)             otx_swap_nlist(nl, n)
#define swap_nlist_64(nl, n, ...)          otx_swap_nlist_64(nl, n)
