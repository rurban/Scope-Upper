/* This file is part of the Scope::Upper Perl module.
 * See http://search.cpan.org/dist/Scope-Upper/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h" 
#include "XSUB.h"

#define __PACKAGE__ "Scope::Upper"

#ifndef SU_DEBUG
# define SU_DEBUG 0
#endif

/* --- Compatibility ------------------------------------------------------- */

#ifndef PERL_UNUSED_VAR
# define PERL_UNUSED_VAR(V)
#endif

#ifndef STMT_START
# define STMT_START do
#endif

#ifndef STMT_END
# define STMT_END while (0)
#endif

#if SU_DEBUG
# define SU_D(X) STMT_START X STMT_END
#else
# define SU_D(X)
#endif

#ifndef Newx
# define Newx(v, n, c) New(0, v, n, c)
#endif

#ifndef SvPV_const
# define SvPV_const(S, L) SvPV(S, L)
#endif

#ifndef SvPV_nolen_const
# define SvPV_nolen_const(S) SvPV_nolen(S)
#endif

#ifndef SvREFCNT_inc_simple_void
# define SvREFCNT_inc_simple_void(sv) SvREFCNT_inc(sv)
#endif

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef gv_fetchpvn_flags
# define gv_fetchpvn_flags(A, B, C, D) gv_fetchpv((A), (C), (D))
#endif

#ifndef PERL_MAGIC_tied
# define PERL_MAGIC_tied 'P'
#endif

#ifndef PERL_MAGIC_env
# define PERL_MAGIC_env 'E'
#endif

#ifndef NEGATIVE_INDICES_VAR
# define NEGATIVE_INDICES_VAR "NEGATIVE_INDICES"
#endif

#define SU_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))
#define SU_HAS_PERL_EXACT(R, V, S) ((PERL_REVISION == (R)) && (PERL_VERSION == (V)) && (PERL_SUBVERSION == (S)))

/* --- Threads and multiplicity -------------------------------------------- */

#ifndef NOOP
# define NOOP
#endif

#ifndef dNOOP
# define dNOOP
#endif

#ifndef SU_MULTIPLICITY
# if defined(MULTIPLICITY) || defined(PERL_IMPLICIT_CONTEXT)
#  define SU_MULTIPLICITY 1
# else
#  define SU_MULTIPLICITY 0
# endif
#endif
#if SU_MULTIPLICITY && !defined(tTHX)
# define tTHX PerlInterpreter*
#endif

#if SU_MULTIPLICITY && defined(USE_ITHREADS) && defined(dMY_CXT) && defined(MY_CXT) && defined(START_MY_CXT) && defined(MY_CXT_INIT) && (defined(MY_CXT_CLONE) || defined(dMY_CXT_SV))
# define SU_THREADSAFE 1
# ifndef MY_CXT_CLONE
#  define MY_CXT_CLONE \
    dMY_CXT_SV;                                                      \
    my_cxt_t *my_cxtp = (my_cxt_t*)SvPVX(newSV(sizeof(my_cxt_t)-1)); \
    Copy(INT2PTR(my_cxt_t*, SvUV(my_cxt_sv)), my_cxtp, 1, my_cxt_t); \
    sv_setuv(my_cxt_sv, PTR2UV(my_cxtp))
# endif
#else
# define SU_THREADSAFE 0
# undef  dMY_CXT
# define dMY_CXT      dNOOP
# undef  MY_CXT
# define MY_CXT       su_globaldata
# undef  START_MY_CXT
# define START_MY_CXT STATIC my_cxt_t MY_CXT;
# undef  MY_CXT_INIT
# define MY_CXT_INIT  NOOP
# undef  MY_CXT_CLONE
# define MY_CXT_CLONE NOOP
#endif

/* --- Global data --------------------------------------------------------- */

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
 char    *stack_placeholder;
 I32      cxix;
 I32      items;
 SV     **savesp;
 LISTOP   return_op;
 OP       proxy_op;
} my_cxt_t;

START_MY_CXT

/* --- Stack manipulations ------------------------------------------------- */

#define SU_SAVE_PLACEHOLDER() save_pptr(&MY_CXT.stack_placeholder)

#define SU_SAVE_DESTRUCTOR_SIZE  3
#define SU_SAVE_PLACEHOLDER_SIZE 3

#define SU_SAVE_SCALAR_SIZE 3

#define SU_SAVE_ARY_SIZE      3
#define SU_SAVE_AELEM_SIZE    4
#ifdef SAVEADELETE
# define SU_SAVE_ADELETE_SIZE 3
#else
# define SU_SAVE_ADELETE_SIZE SU_SAVE_DESTRUCTOR_SIZE
#endif
#if SU_SAVE_AELEM_SIZE < SU_SAVE_ADELETE_SIZE
# define SU_SAVE_AELEM_OR_ADELETE_SIZE SU_SAVE_ADELETE_SIZE
#else
# define SU_SAVE_AELEM_OR_ADELETE_SIZE SU_SAVE_AELEM_SIZE
#endif

#define SU_SAVE_HASH_SIZE    3
#define SU_SAVE_HELEM_SIZE   4
#define SU_SAVE_HDELETE_SIZE 4
#if SU_SAVE_HELEM_SIZE < SU_SAVE_HDELETE_SIZE
# define SU_SAVE_HELEM_OR_HDELETE_SIZE SU_SAVE_HDELETE_SIZE
#else
# define SU_SAVE_HELEM_OR_HDELETE_SIZE SU_SAVE_HELEM_SIZE
#endif

#define SU_SAVE_SPTR_SIZE 3

#if !SU_HAS_PERL(5, 8, 9)
# define SU_SAVE_GP_SIZE 6
#elif !SU_HAS_PERL(5, 13, 0) || (SU_RELEASE && SU_HAS_PERL_EXACT(5, 13, 0))
# define SU_SAVE_GP_SIZE 3
#elif !SU_HAS_PERL(5, 13, 8)
# define SU_SAVE_GP_SIZE 4
#else
# define SU_SAVE_GP_SIZE 3
#endif

#ifndef SvCANEXISTDELETE
# define SvCANEXISTDELETE(sv) \
  (!SvRMAGICAL(sv)            \
   || ((mg = mg_find((SV *) sv, PERL_MAGIC_tied))            \
       && (stash = SvSTASH(SvRV(SvTIED_obj((SV *) sv, mg)))) \
       && gv_fetchmethod_autoload(stash, "EXISTS", TRUE)     \
       && gv_fetchmethod_autoload(stash, "DELETE", TRUE)     \
      )                       \
   )
#endif

/* ... Saving array elements ............................................... */

STATIC I32 su_av_key2idx(pTHX_ AV *av, I32 key) {
#define su_av_key2idx(A, K) su_av_key2idx(aTHX_ (A), (K))
 I32 idx;

 if (key >= 0)
  return key;

/* Added by MJD in perl-5.8.1 with 6f12eb6d2a1dfaf441504d869b27d2e40ef4966a */
#if SU_HAS_PERL(5, 8, 1)
 if (SvRMAGICAL(av)) {
  const MAGIC * const tied_magic = mg_find((SV *) av, PERL_MAGIC_tied);
  if (tied_magic) {
   SV * const * const negative_indices_glob =
                    hv_fetch(SvSTASH(SvRV(SvTIED_obj((SV *) (av), tied_magic))),
                             NEGATIVE_INDICES_VAR, 16, 0);
   if (negative_indices_glob && SvTRUE(GvSV(*negative_indices_glob)))
    return key;
  }
 }
#endif

 idx = key + av_len(av) + 1;
 if (idx < 0)
  return key;

 return idx;
}

#ifndef SAVEADELETE

typedef struct {
 AV *av;
 I32 idx;
} su_ud_adelete;

STATIC void su_adelete(pTHX_ void *ud_) {
 su_ud_adelete *ud = (su_ud_adelete *) ud_;

 av_delete(ud->av, ud->idx, G_DISCARD);
 SvREFCNT_dec(ud->av);

 Safefree(ud);
}

STATIC void su_save_adelete(pTHX_ AV *av, I32 idx) {
#define su_save_adelete(A, K) su_save_adelete(aTHX_ (A), (K))
 su_ud_adelete *ud;

 Newx(ud, 1, su_ud_adelete);
 ud->av  = av;
 ud->idx = idx;
 SvREFCNT_inc_simple_void(av);

 SAVEDESTRUCTOR_X(su_adelete, ud);
}

#define SAVEADELETE(A, K) su_save_adelete((A), (K))

#endif /* SAVEADELETE */

STATIC void su_save_aelem(pTHX_ AV *av, SV *key, SV *val) {
#define su_save_aelem(A, K, V) su_save_aelem(aTHX_ (A), (K), (V))
 I32 idx;
 I32 preeminent = 1;
 SV **svp;
 HV *stash;
 MAGIC *mg;

 idx = su_av_key2idx(av, SvIV(key));

 if (SvCANEXISTDELETE(av))
  preeminent = av_exists(av, idx);

 svp = av_fetch(av, idx, 1);
 if (!svp || *svp == &PL_sv_undef) croak(PL_no_aelem, idx);

 if (preeminent)
  save_aelem(av, idx, svp);
 else
  SAVEADELETE(av, idx);

 if (val) { /* local $x[$idx] = $val; */
  SvSetMagicSV(*svp, val);
 } else {   /* local $x[$idx]; delete $x[$idx]; */
  av_delete(av, idx, G_DISCARD);
 }
}

/* ... Saving hash elements ................................................ */

STATIC void su_save_helem(pTHX_ HV *hv, SV *keysv, SV *val) {
#define su_save_helem(H, K, V) su_save_helem(aTHX_ (H), (K), (V))
 I32 preeminent = 1;
 HE *he;
 SV **svp;
 HV *stash;
 MAGIC *mg;

 if (SvCANEXISTDELETE(hv) || mg_find((SV *) hv, PERL_MAGIC_env))
  preeminent = hv_exists_ent(hv, keysv, 0);

 he  = hv_fetch_ent(hv, keysv, 1, 0);
 svp = he ? &HeVAL(he) : NULL;
 if (!svp || *svp == &PL_sv_undef) croak("Modification of non-creatable hash value attempted, subscript \"%s\"", SvPV_nolen_const(*svp));

 if (HvNAME_get(hv) && isGV(*svp)) {
  save_gp((GV *) *svp, 0);
  return;
 }

 if (preeminent)
  save_helem(hv, keysv, svp);
 else {
  STRLEN keylen;
  const char * const key = SvPV_const(keysv, keylen);
  SAVEDELETE(hv, savepvn(key, keylen),
                 SvUTF8(keysv) ? -(I32)keylen : (I32)keylen);
 }

 if (val) { /* local $x{$keysv} = $val; */
  SvSetMagicSV(*svp, val);
 } else {   /* local $x{$keysv}; delete $x{$keysv}; */
  (void)hv_delete_ent(hv, keysv, G_DISCARD, HeHASH(he));
 }
}

/* --- Actions ------------------------------------------------------------- */

typedef struct {
 I32 depth;
 I32 pad;
 I32 *origin;
 void (*handler)(pTHX_ void *);
} su_ud_common;

#define SU_UD_DEPTH(U)   (((su_ud_common *) (U))->depth)
#define SU_UD_PAD(U)     (((su_ud_common *) (U))->pad)
#define SU_UD_ORIGIN(U)  (((su_ud_common *) (U))->origin)
#define SU_UD_HANDLER(U) (((su_ud_common *) (U))->handler)

#define SU_UD_FREE(U) STMT_START { \
 if (SU_UD_ORIGIN(U)) Safefree(SU_UD_ORIGIN(U)); \
 Safefree(U); \
} STMT_END

/* ... Reap ................................................................ */

typedef struct {
 su_ud_common ci;
 SV *cb;
} su_ud_reap;

STATIC void su_call(pTHX_ void *ud_) {
 su_ud_reap *ud = (su_ud_reap *) ud_;
#if SU_HAS_PERL(5, 9, 5)
 PERL_CONTEXT saved_cx;
 I32 cxix;
#endif

 dSP;

 SU_D({
  PerlIO_printf(Perl_debug_log,
                "%p: @@@ call\n%p: depth=%2d scope_ix=%2d save_ix=%2d\n",
                 ud, ud, SU_UD_DEPTH(ud), PL_scopestack_ix, PL_savestack_ix);
 });

 ENTER;
 SAVETMPS;

 PUSHMARK(SP);
 PUTBACK;

 /* If the recently popped context isn't saved there, it will be overwritten by
  * the sub scope from call_sv, although it's still needed in our caller. */

#if SU_HAS_PERL(5, 9, 5)
 if (cxstack_ix < cxstack_max)
  cxix = cxstack_ix + 1;
 else
  cxix = Perl_cxinc(aTHX);
 saved_cx = cxstack[cxix];
#endif

 call_sv(ud->cb, G_VOID);

#if SU_HAS_PERL(5, 9, 5)
 cxstack[cxix] = saved_cx;
#endif

 PUTBACK;

 FREETMPS;
 LEAVE;

 SvREFCNT_dec(ud->cb);
 SU_UD_FREE(ud);
}

STATIC void su_reap(pTHX_ void *ud) {
#define su_reap(U) su_reap(aTHX_ (U))
 SU_D({
  PerlIO_printf(Perl_debug_log,
                "%p: === reap\n%p: depth=%2d scope_ix=%2d save_ix=%2d\n",
                 ud, ud, SU_UD_DEPTH(ud), PL_scopestack_ix, PL_savestack_ix);
 });

 SAVEDESTRUCTOR_X(su_call, ud);
}

/* ... Localize & localize array/hash element .............................. */

typedef struct {
 su_ud_common ci;
 SV    *sv;
 SV    *val;
 SV    *elem;
 svtype type;
} su_ud_localize;

#define SU_UD_LOCALIZE_FREE(U) STMT_START { \
 SvREFCNT_dec((U)->elem); \
 SvREFCNT_dec((U)->val);  \
 SvREFCNT_dec((U)->sv);   \
 SU_UD_FREE(U);           \
} STMT_END

STATIC I32 su_ud_localize_init(pTHX_ su_ud_localize *ud, SV *sv, SV *val, SV *elem) {
#define su_ud_localize_init(UD, S, V, E) su_ud_localize_init(aTHX_ (UD), (S), (V), (E))
 UV deref = 0;
 svtype t = SVt_NULL;
 I32 size;

 SvREFCNT_inc_simple_void(sv);

 if (SvTYPE(sv) >= SVt_PVGV) {
  if (!val || !SvROK(val)) { /* local *x; or local *x = $val; */
   t = SVt_PVGV;
  } else {                   /* local *x = \$val; */
   t = SvTYPE(SvRV(val));
   deref = 1;
  }
 } else if (SvROK(sv)) {
  croak("Invalid %s reference as the localization target",
                 sv_reftype(SvRV(sv), 0));
 } else {
  STRLEN len, l;
  const char *p = SvPV_const(sv, len), *s;
  for (s = p, l = len; l > 0 && isSPACE(*s); ++s, --l) { }
  if (!l) {
   l = len;
   s = p;
  }
  switch (*s) {
   case '$': t = SVt_PV;   break;
   case '@': t = SVt_PVAV; break;
   case '%': t = SVt_PVHV; break;
   case '&': t = SVt_PVCV; break;
   case '*': t = SVt_PVGV; break;
  }
  if (t != SVt_NULL) {
   ++s;
   --l;
  } else if (val) { /* t == SVt_NULL, type can't be inferred from the sigil */
   if (SvROK(val) && !sv_isobject(val)) {
    t = SvTYPE(SvRV(val));
    deref = 1;
   } else {
    t = SvTYPE(val);
   }
  }
  SvREFCNT_dec(sv);
  sv = newSVpvn(s, l);
 }

 switch (t) {
  case SVt_PVAV:
   size  = elem ? SU_SAVE_AELEM_OR_ADELETE_SIZE
                : SU_SAVE_ARY_SIZE;
   deref = 0;
   break;
  case SVt_PVHV:
   size  = elem ? SU_SAVE_HELEM_OR_HDELETE_SIZE
                : SU_SAVE_HASH_SIZE;
   deref = 0;
   break;
  case SVt_PVGV:
   size  = SU_SAVE_GP_SIZE;
   deref = 0;
   break;
  case SVt_PVCV:
   size  = SU_SAVE_SPTR_SIZE;
   deref = 0;
   break;
  default:
   size = SU_SAVE_SCALAR_SIZE;
   break;
 }
 /* When deref is set, val isn't NULL */

 ud->sv   = sv;
 ud->val  = val ? newSVsv(deref ? SvRV(val) : val) : NULL;
 ud->elem = SvREFCNT_inc(elem);
 ud->type = t;

 return size;
}

STATIC void su_localize(pTHX_ void *ud_) {
#define su_localize(U) su_localize(aTHX_ (U))
 su_ud_localize *ud = (su_ud_localize *) ud_;
 SV *sv   = ud->sv;
 SV *val  = ud->val;
 SV *elem = ud->elem;
 svtype t = ud->type;
 GV *gv;

 if (SvTYPE(sv) >= SVt_PVGV) {
  gv = (GV *) sv;
 } else {
#ifdef gv_fetchsv
  gv = gv_fetchsv(sv, GV_ADDMULTI, t);
#else
  STRLEN len;
  const char *name = SvPV_const(sv, len);
  gv = gv_fetchpvn_flags(name, len, GV_ADDMULTI, t);
#endif
 }

 SU_D({
  SV *z = newSV(0);
  SvUPGRADE(z, t);
  PerlIO_printf(Perl_debug_log, "%p: === localize a %s\n",ud, sv_reftype(z, 0));
  PerlIO_printf(Perl_debug_log,
                "%p: depth=%2d scope_ix=%2d save_ix=%2d\n",
                 ud, SU_UD_DEPTH(ud), PL_scopestack_ix, PL_savestack_ix);
  SvREFCNT_dec(z);
 });

 /* Inspired from Alias.pm */
 switch (t) {
  case SVt_PVAV:
   if (elem) {
    su_save_aelem(GvAV(gv), elem, val);
    goto done;
   } else
    save_ary(gv);
   break;
  case SVt_PVHV:
   if (elem) {
    su_save_helem(GvHV(gv), elem, val);
    goto done;
   } else
    save_hash(gv);
   break;
  case SVt_PVGV:
   save_gp(gv, 1); /* hide previous entry in symtab */
   break;
  case SVt_PVCV:
   SAVESPTR(GvCV(gv));
   GvCV(gv) = NULL;
   break;
  default:
   gv = (GV *) save_scalar(gv);
   break;
 }

 if (val)
  SvSetMagicSV((SV *) gv, val);

done:
 SU_UD_LOCALIZE_FREE(ud);
}

/* --- Pop a context back -------------------------------------------------- */

#if SU_DEBUG
# ifdef DEBUGGING
#  define SU_CXNAME PL_block_type[CxTYPE(&cxstack[cxstack_ix])]
# else
#  define SU_CXNAME "XXX"
# endif
#endif

STATIC void su_pop(pTHX_ void *ud) {
#define su_pop(U) su_pop(aTHX_ (U))
 I32 depth, base, mark, *origin;
 depth = SU_UD_DEPTH(ud);

 SU_D(
  PerlIO_printf(Perl_debug_log,
   "%p: --- pop a %s\n"
   "%p: leave scope     at depth=%2d scope_ix=%2d cur_top=%2d cur_base=%2d\n",
    ud, SU_CXNAME,
    ud, depth, PL_scopestack_ix,PL_savestack_ix,PL_scopestack[PL_scopestack_ix])
 );

 origin = SU_UD_ORIGIN(ud);
 mark   = origin[depth];
 base   = origin[depth - 1];

 SU_D(PerlIO_printf(Perl_debug_log,
                    "%p: original scope was %*c top=%2d     base=%2d\n",
                     ud,                24, ' ',    mark,        base));

 if (base < mark) {
  SU_D(PerlIO_printf(Perl_debug_log, "%p: clear leftovers\n", ud));
  PL_savestack_ix = mark;
  leave_scope(base);
 }
 PL_savestack_ix = base;

 SU_UD_DEPTH(ud) = --depth;

 if (depth > 0) {
  I32 pad;

  if ((pad = SU_UD_PAD(ud))) {
   dMY_CXT;
   do {
    SU_D(PerlIO_printf(Perl_debug_log,
          "%p: push a pad slot at depth=%2d scope_ix=%2d save_ix=%2d\n",
           ud,                       depth, PL_scopestack_ix, PL_savestack_ix));
    SU_SAVE_PLACEHOLDER();
   } while (--pad);
  }

  SU_D(PerlIO_printf(Perl_debug_log,
          "%p: push destructor at depth=%2d scope_ix=%2d save_ix=%2d\n",
           ud,                       depth, PL_scopestack_ix, PL_savestack_ix));
  SAVEDESTRUCTOR_X(su_pop, ud);
 } else {
  SU_UD_HANDLER(ud)(aTHX_ ud);
 }

 SU_D(PerlIO_printf(Perl_debug_log,
                    "%p: --- end pop: cur_top=%2d == cur_base=%2d\n",
                     ud, PL_savestack_ix, PL_scopestack[PL_scopestack_ix]));
}

/* --- Initialize the stack and the action userdata ------------------------ */

STATIC I32 su_init(pTHX_ void *ud, I32 cxix, I32 size) {
#define su_init(U, C, S) su_init(aTHX_ (U), (C), (S))
 I32 i, depth = 1, pad, offset, *origin;

 SU_D(PerlIO_printf(Perl_debug_log, "%p: ### init for cx %d\n", ud, cxix));

 if (size <= SU_SAVE_DESTRUCTOR_SIZE)
  pad = 0;
 else {
  I32 extra = size - SU_SAVE_DESTRUCTOR_SIZE;
  pad = extra / SU_SAVE_PLACEHOLDER_SIZE;
  if (extra % SU_SAVE_PLACEHOLDER_SIZE)
   ++pad;
 }
 offset = SU_SAVE_DESTRUCTOR_SIZE + SU_SAVE_PLACEHOLDER_SIZE * pad;

 SU_D(PerlIO_printf(Perl_debug_log, "%p: size=%d pad=%d offset=%d\n",
                                     ud,    size,   pad,   offset));

 for (i = cxstack_ix; i > cxix; --i) {
  PERL_CONTEXT *cx = cxstack + i;
  switch (CxTYPE(cx)) {
#if SU_HAS_PERL(5, 10, 0)
   case CXt_BLOCK:
    SU_D(PerlIO_printf(Perl_debug_log, "%p: cx %d is block\n", ud, i));
    /* Given and when blocks are actually followed by a simple block, so skip
     * it if needed. */
    if (cxix > 0) { /* Implies i > 0 */
     PERL_CONTEXT *next = cx - 1;
     if (CxTYPE(next) == CXt_GIVEN || CxTYPE(next) == CXt_WHEN)
      --cxix;
    }
    depth++;
    break;
#endif
#if SU_HAS_PERL(5, 11, 0)
   case CXt_LOOP_FOR:
   case CXt_LOOP_PLAIN:
   case CXt_LOOP_LAZYSV:
   case CXt_LOOP_LAZYIV:
#else
   case CXt_LOOP:
#endif
    SU_D(PerlIO_printf(Perl_debug_log, "%p: cx %d is loop\n", ud, i));
    depth += 2;
    break;
   default:
    SU_D(PerlIO_printf(Perl_debug_log, "%p: cx %d is other\n", ud, i));
    depth++;
    break;
  }
 }
 SU_D(PerlIO_printf(Perl_debug_log, "%p: going down to depth %d\n", ud, depth));

 Newx(origin, depth + 1, I32);
 origin[0] = PL_scopestack[PL_scopestack_ix - depth];
 PL_scopestack[PL_scopestack_ix - depth] += size;
 for (i = depth - 1; i >= 1; --i) {
  I32 j = PL_scopestack_ix - i;
  origin[depth - i] = PL_scopestack[j];
  PL_scopestack[j] += offset;
 }
 origin[depth] = PL_savestack_ix;

 SU_UD_ORIGIN(ud) = origin;
 SU_UD_DEPTH(ud)  = depth;
 SU_UD_PAD(ud)    = pad;

 /* Make sure the first destructor fires by pushing enough fake slots on the
  * stack. */
 if (PL_savestack_ix + SU_SAVE_DESTRUCTOR_SIZE
                                       <= PL_scopestack[PL_scopestack_ix - 1]) {
  dMY_CXT;
  do {
   SU_D(PerlIO_printf(Perl_debug_log,
                  "%p: push a fake slot      at scope_ix=%2d  save_ix=%2d\n",
                   ud,                      PL_scopestack_ix, PL_savestack_ix));
   SU_SAVE_PLACEHOLDER();
  } while (PL_savestack_ix + SU_SAVE_DESTRUCTOR_SIZE
                                        <= PL_scopestack[PL_scopestack_ix - 1]);
 }
 SU_D(PerlIO_printf(Perl_debug_log,
                  "%p: push first destructor at scope_ix=%2d  save_ix=%2d\n",
                   ud,                      PL_scopestack_ix, PL_savestack_ix));
 SAVEDESTRUCTOR_X(su_pop, ud);

 SU_D({
  for (i = 0; i <= depth; ++i) {
   I32 j = PL_scopestack_ix  - i;
   PerlIO_printf(Perl_debug_log,
                 "%p: depth=%2d scope_ix=%2d saved_floor=%2d new_floor=%2d\n",
                  ud,        i, j, origin[depth - i],
                                   i == 0 ? PL_savestack_ix : PL_scopestack[j]);
  }
 });

 return depth;
}

/* --- Unwind stack -------------------------------------------------------- */

STATIC void su_unwind(pTHX_ void *ud_) {
 dMY_CXT;
 I32 cxix    = MY_CXT.cxix;
 I32 items   = MY_CXT.items - 1;
 SV **savesp = MY_CXT.savesp;
 I32 mark;

 PERL_UNUSED_VAR(ud_);

 if (savesp)
  PL_stack_sp = savesp;

 if (cxstack_ix > cxix)
  dounwind(cxix);

 /* Hide the level */
 if (items >= 0)
  PL_stack_sp--;

 mark = PL_markstack[cxstack[cxix].blk_oldmarksp];
 *PL_markstack_ptr = PL_stack_sp - PL_stack_base - items;

 SU_D({
  I32 gimme = GIMME_V;
  PerlIO_printf(Perl_debug_log,
                "%p: cx=%d gimme=%s items=%d sp=%d oldmark=%d mark=%d\n",
                &MY_CXT, cxix,
                gimme == G_VOID ? "void" : gimme == G_ARRAY ? "list" : "scalar",
                items, PL_stack_sp - PL_stack_base, *PL_markstack_ptr, mark);
 });

 PL_op = (OP *) &(MY_CXT.return_op);
 PL_op = PL_op->op_ppaddr(aTHX);

 *PL_markstack_ptr = mark;

 MY_CXT.proxy_op.op_next = PL_op;
 PL_op = &(MY_CXT.proxy_op);
}

/* --- XS ------------------------------------------------------------------ */

#if SU_HAS_PERL(5, 8, 9)
# define SU_SKIP_DB_MAX 2
#else
# define SU_SKIP_DB_MAX 3
#endif

/* Skip context sequences of 1 to SU_SKIP_DB_MAX (included) block contexts
 * followed by a DB sub */

#define SU_SKIP_DB(C) \
 STMT_START {         \
  I32 skipped = 0;    \
  PERL_CONTEXT *base = cxstack;      \
  PERL_CONTEXT *cx   = base + (C);   \
  while (cx >= base && (C) > skipped && CxTYPE(cx) == CXt_BLOCK) \
   --cx, ++skipped;                  \
  if (cx >= base && (C) > skipped) { \
   switch (CxTYPE(cx)) {  \
    case CXt_SUB:         \
     if (skipped <= SU_SKIP_DB_MAX && cx->blk_sub.cv == GvCV(PL_DBsub)) \
      (C) -= skipped + 1; \
      break;              \
    default:              \
     break;               \
   }                      \
  }                       \
 } STMT_END

#define SU_GET_CONTEXT(A, B)   \
 STMT_START {                  \
  if (items > A) {             \
   SV *csv = ST(B);            \
   if (!SvOK(csv))             \
    goto default_cx;           \
   cxix = SvIV(csv);           \
   if (cxix < 0)               \
    cxix = 0;                  \
   else if (cxix > cxstack_ix) \
    cxix = cxstack_ix;         \
  } else {                     \
default_cx:                    \
   cxix = cxstack_ix;          \
   if (PL_DBsub)               \
    SU_SKIP_DB(cxix);          \
  }                            \
 } STMT_END

#define SU_GET_LEVEL(A, B) \
 STMT_START {              \
  level = 0;               \
  if (items > 0) {         \
   SV *lsv = ST(B);        \
   if (SvOK(lsv)) {        \
    level = SvIV(lsv);     \
    if (level < 0)         \
     level = 0;            \
   }                       \
  }                        \
 } STMT_END

XS(XS_Scope__Upper_unwind); /* prototype to pass -Wmissing-prototypes */

XS(XS_Scope__Upper_unwind) {
#ifdef dVAR
 dVAR; dXSARGS;
#else
 dXSARGS;
#endif
 dMY_CXT;
 I32 cxix;

 PERL_UNUSED_VAR(cv); /* -W */
 PERL_UNUSED_VAR(ax); /* -Wall */

 SU_GET_CONTEXT(0, items - 1);
 do {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
   case CXt_EVAL:
   case CXt_FORMAT:
    MY_CXT.cxix  = cxix;
    MY_CXT.items = items;
    /* pp_entersub will want to sanitize the stack after returning from there
     * Screw that, we're insane */
    if (GIMME_V == G_SCALAR) {
     MY_CXT.savesp = PL_stack_sp;
     /* dXSARGS calls POPMARK, so we need to match PL_markstack_ptr[1] */
     PL_stack_sp = PL_stack_base + PL_markstack_ptr[1] + 1;
    } else {
     MY_CXT.savesp = NULL;
    }
    SAVEDESTRUCTOR_X(su_unwind, NULL);
    return;
   default:
    break;
  }
 } while (--cxix >= 0);
 croak("Can't return outside a subroutine");
}

MODULE = Scope::Upper            PACKAGE = Scope::Upper

PROTOTYPES: ENABLE

BOOT:
{
 HV *stash;

 MY_CXT_INIT;

 MY_CXT.stack_placeholder = NULL;

 /* NewOp() calls calloc() which just zeroes the memory with memset(). */
 Zero(&(MY_CXT.return_op), 1, sizeof(MY_CXT.return_op));
 MY_CXT.return_op.op_type   = OP_RETURN;
 MY_CXT.return_op.op_ppaddr = PL_ppaddr[OP_RETURN];

 Zero(&(MY_CXT.proxy_op), 1, sizeof(MY_CXT.proxy_op));
 MY_CXT.proxy_op.op_type   = OP_STUB;
 MY_CXT.proxy_op.op_ppaddr = NULL;

 stash = gv_stashpv(__PACKAGE__, 1);
 newCONSTSUB(stash, "TOP",           newSViv(0));
 newCONSTSUB(stash, "SU_THREADSAFE", newSVuv(SU_THREADSAFE));

 newXSproto("Scope::Upper::unwind", XS_Scope__Upper_unwind, file, NULL);
}

#if SU_THREADSAFE

void
CLONE(...)
PROTOTYPE: DISABLE
PPCODE:
 {
  MY_CXT_CLONE;
 }
 XSRETURN(0);

#endif /* SU_THREADSAFE */

SV *
HERE()
PROTOTYPE:
PREINIT:
 I32 cxix = cxstack_ix;
CODE:
 if (PL_DBsub)
  SU_SKIP_DB(cxix);
 RETVAL = newSViv(cxix);
OUTPUT:
 RETVAL

SV *
UP(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
CODE:
 SU_GET_CONTEXT(0, 0);
 if (--cxix < 0)
  cxix = 0;
 if (PL_DBsub)
  SU_SKIP_DB(cxix);
 RETVAL = newSViv(cxix);
OUTPUT:
 RETVAL

void
SUB(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0);
 for (; cxix >= 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   default:
    continue;
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
    ST(0) = sv_2mortal(newSViv(cxix));
    XSRETURN(1);
  }
 }
 XSRETURN_UNDEF;

void
EVAL(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0);
 for (; cxix >= 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   default:
    continue;
   case CXt_EVAL:
    ST(0) = sv_2mortal(newSViv(cxix));
    XSRETURN(1);
  }
 }
 XSRETURN_UNDEF;

void
SCOPE(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix, level;
PPCODE:
 SU_GET_LEVEL(0, 0);
 cxix = cxstack_ix;
 if (PL_DBsub) {
  SU_SKIP_DB(cxix);
  while (cxix > 0) {
   if (--level < 0)
    break;
   --cxix;
   SU_SKIP_DB(cxix);
  }
 } else {
  cxix -= level;
  if (cxix < 0)
   cxix = 0;
 }
 ST(0) = sv_2mortal(newSViv(cxix));
 XSRETURN(1);

void
CALLER(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix, level;
PPCODE:
 SU_GET_LEVEL(0, 0);
 for (cxix = cxstack_ix; cxix > 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
   case CXt_EVAL:
   case CXt_FORMAT:
    if (--level < 0)
     goto done;
    break;
  }
 }
done:
 ST(0) = sv_2mortal(newSViv(cxix));
 XSRETURN(1);

void
want_at(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0);
 while (cxix > 0) {
  PERL_CONTEXT *cx = cxstack + cxix--;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
   case CXt_EVAL:
   case CXt_FORMAT: {
    I32 gimme = cx->blk_gimme;
    switch (gimme) {
     case G_VOID:   XSRETURN_UNDEF; break;
     case G_SCALAR: XSRETURN_NO;    break;
     case G_ARRAY:  XSRETURN_YES;   break;
    }
    break;
   }
  }
 }
 XSRETURN_UNDEF;

void
reap(SV *hook, ...)
PROTOTYPE: &;$
PREINIT:
 I32 cxix;
 su_ud_reap *ud;
CODE:
 SU_GET_CONTEXT(1, 1);
 Newx(ud, 1, su_ud_reap);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_reap;
 ud->cb = newSVsv(hook);
 su_init(ud, cxix, SU_SAVE_DESTRUCTOR_SIZE);

void
localize(SV *sv, SV *val, ...)
PROTOTYPE: $$;$
PREINIT:
 I32 cxix;
 I32 size;
 su_ud_localize *ud;
CODE:
 SU_GET_CONTEXT(2, 2);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 size = su_ud_localize_init(ud, sv, val, NULL);
 su_init(ud, cxix, size);

void
localize_elem(SV *sv, SV *elem, SV *val, ...)
PROTOTYPE: $$$;$
PREINIT:
 I32 cxix;
 I32 size;
 su_ud_localize *ud;
CODE:
 if (SvTYPE(sv) >= SVt_PVGV)
  croak("Can't infer the element localization type from a glob and the value");
 SU_GET_CONTEXT(3, 3);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 size = su_ud_localize_init(ud, sv, val, elem);
 if (ud->type != SVt_PVAV && ud->type != SVt_PVHV) {
  SU_UD_LOCALIZE_FREE(ud);
  croak("Can't localize an element of something that isn't an array or a hash");
 }
 su_init(ud, cxix, size);

void
localize_delete(SV *sv, SV *elem, ...)
PROTOTYPE: $$;$
PREINIT:
 I32 cxix;
 I32 size;
 su_ud_localize *ud;
CODE:
 SU_GET_CONTEXT(2, 2);
 Newx(ud, 1, su_ud_localize);
 SU_UD_ORIGIN(ud)  = NULL;
 SU_UD_HANDLER(ud) = su_localize;
 size = su_ud_localize_init(ud, sv, NULL, elem);
 su_init(ud, cxix, size);
