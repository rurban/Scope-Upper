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

#ifndef NOOP
# define NOOP
#endif

#ifndef dNOOP
# define dNOOP
#endif

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

#ifdef DEBUGGING
# ifdef PoisonNew
#  define SU_POISON(D, N, T) PoisonNew((D), (N), T)
# elif defined(Poison)
#  define SU_POISON(D, N, T) Poison((D), (N), T)
# endif
#endif
#ifndef SU_POISON
# define SU_POISON(D, N, T) NOOP
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

#ifndef GvCV_set
# define GvCV_set(G, C) (GvCV(G) = (C))
#endif

#ifndef CvGV_set
# define CvGV_set(C, G) (CvGV(C) = (G))
#endif

#ifndef CxHASARGS
# define CxHASARGS(C) ((C)->blk_sub.hasargs)
#endif

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef gv_fetchpvn_flags
# define gv_fetchpvn_flags(A, B, C, D) gv_fetchpv((A), (C), (D))
#endif

#ifndef cv_clone
# define cv_clone(P) Perl_cv_clone(aTHX_ (P))
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

/* --- uplevel() data tokens ----------------------------------------------- */

typedef struct {
 void *next;

 I32  cxix;
 CV  *target;
 bool died;

 PERL_SI *si;
 PERL_SI *old_curstackinfo;
 AV      *old_mainstack;

 I32  old_depth;
 COP *old_curcop;

 bool old_catch;
 OP  *old_op;
 CV  *cloned_cv;
} su_uplevel_ud;

STATIC su_uplevel_ud *su_uplevel_ud_new(pTHX) {
#define su_uplevel_ud_new() su_uplevel_ud_new(aTHX)
 su_uplevel_ud *sud;
 PERL_SI       *si;

 Newx(sud, 1, su_uplevel_ud);
 sud->next = NULL;

 Newx(si, 1, PERL_SI);
 si->si_stack   = newAV();
 AvREAL_off(si->si_stack);
 si->si_cxstack = NULL;
 sud->si = si;

 return sud;
}

STATIC void su_uplevel_ud_delete(pTHX_ su_uplevel_ud *sud) {
#define su_uplevel_ud_delete(S) su_uplevel_ud_delete(aTHX_ (S))
 PERL_SI *si = sud->si;

 Safefree(si->si_cxstack);
 SvREFCNT_dec(si->si_stack);
 Safefree(si);
 Safefree(sud);

 return;
}

typedef struct {
 su_uplevel_ud *root;
 I32            count;
} su_uplevel_storage;

#ifndef SU_UPLEVEL_STORAGE_SIZE
# define SU_UPLEVEL_STORAGE_SIZE 4
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

 su_uplevel_storage uplevel_storage;
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

#define SU_SAVE_GVCV_SIZE SU_SAVE_DESTRUCTOR_SIZE

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

/* ... Saving code slots from a glob ....................................... */

#if !SU_HAS_PERL(5, 10, 0) && !defined(mro_method_changed_in)
# define mro_method_changed_in(G) PL_sub_generation++
#endif

typedef struct {
 GV *gv;
 CV *old_cv;
} su_save_gvcv_ud;

STATIC void su_restore_gvcv(pTHX_ void *ud_) {
 su_save_gvcv_ud *ud = ud_;
 GV              *gv = ud->gv;

 GvCV_set(gv, ud->old_cv);
 GvCVGEN(gv) = 0;
 mro_method_changed_in(GvSTASH(gv));

 Safefree(ud);
}

STATIC void su_save_gvcv(pTHX_ GV *gv) {
#define su_save_gvcv(G) su_save_gvcv(aTHX_ (G))
 su_save_gvcv_ud *ud;

 Newx(ud, 1, su_save_gvcv_ud);
 ud->gv     = gv;
 ud->old_cv = GvCV(gv);

 GvCV_set(gv, NULL);
 GvCVGEN(gv) = 0;
 mro_method_changed_in(GvSTASH(gv));

 SAVEDESTRUCTOR_X(su_restore_gvcv, ud);
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
   size  = SU_SAVE_GVCV_SIZE;
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
   su_save_gvcv(gv);
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

/* --- Uplevel ------------------------------------------------------------- */

#ifndef OP_GIMME_REVERSE
STATIC U8 su_op_gimme_reverse(U8 gimme) {
 switch (gimme) {
  case G_VOID:
   return OPf_WANT_VOID;
  case G_ARRAY:
   return OPf_WANT_LIST;
  default:
   break;
 }

 return OPf_WANT_SCALAR;
}
#define OP_GIMME_REVERSE(G) su_op_gimme_reverse(G)
#endif

#define SU_UPLEVEL_SAVE(f, t) STMT_START { sud->old_##f = PL_##f; PL_##f = (t); } STMT_END
#define SU_UPLEVEL_RESTORE(f) STMT_START { PL_##f = sud->old_##f; } STMT_END

STATIC int su_uplevel_restore_free(pTHX_ SV *sv, MAGIC *mg) {
 su_uplevel_ud_delete((su_uplevel_ud *) mg->mg_ptr);

 return 0;
}

STATIC MGVTBL su_uplevel_restore_vtbl = {
 0,
 0,
 0,
 0,
 su_uplevel_restore_free
};

STATIC void su_uplevel_restore(pTHX_ void *sus_) {
 su_uplevel_ud *sud = sus_;
 PERL_SI *cur = sud->old_curstackinfo;
 PERL_SI *si  = sud->si;
 dMY_CXT;

 /* When we reach this place, POPSUB has already been called (with our fake
  * argarray). GvAV(PL_defgv) points to the savearray (that is, what @_ was
  * before uplevel). argarray is either the fake AV we created in su_uplevel()
  * or some empty replacement POPSUB creates when @_ is reified. In both cases
  * we have to destroy it before the context stack is swapped back to its
  * original state. */
 SvREFCNT_dec(cxstack[sud->cxix].blk_sub.argarray);

 CATCH_SET(sud->old_catch);

 SvREFCNT_dec(sud->cloned_cv);

 SU_UPLEVEL_RESTORE(op);

 /* stack_grow() wants PL_curstack so restore the old stack first */
 if (PL_curstackinfo == si) {
  PL_curstack = cur->si_stack;
  if (sud->old_mainstack)
   SU_UPLEVEL_RESTORE(mainstack);
  SU_UPLEVEL_RESTORE(curstackinfo);

  if (sud->died) {
   CV *target_cv = sud->target;
   I32 levels = 0, i;

   /* When we die, the depth of the target CV is not updated because of the
    * stack switcheroo. So we have to look at all the frames between the
    * uplevel call and the catch block to count how many call frames to the
    * target CV were skipped. */
   for (i = cur->si_cxix; i > sud->cxix; i--) {
    register const PERL_CONTEXT *cx = cxstack + i;

    if (CxTYPE(cx) == CXt_SUB) {
     if (cx->blk_sub.cv == target_cv)
      ++levels;
    }
   }

   /* If we died, the replacement stack was already unwinded to the first
    * eval frame, and all the contexts down there were popped. We don't have
    * to pop manually any context of the original stack, because they must
    * have been in the replacement stack as well (since the second was copied
    * from the first). Thus we only have to make sure the original stack index
    * points to the context just below the first eval scope under the target
    * frame. */
   for (; i >= 0; i--) {
    register const PERL_CONTEXT *cx = cxstack + i;

    switch (CxTYPE(cx)) {
     case CXt_SUB:
      if (cx->blk_sub.cv == target_cv)
       ++levels;
      break;
     case CXt_EVAL:
      goto found_it;
      break;
     default:
      break;
    }
   }

found_it:
   CvDEPTH(target_cv) = sud->old_depth - levels;
   PL_curstackinfo->si_cxix = i - 1;

#if !SU_HAS_PERL(5, 13, 1)
   /* Since $@ was maybe localized between the target frame and the uplevel
    * call, we forcefully flush the save stack to get rid of it and then
    * reset $@ to its proper value. Note that the the call to
    * su_uplevel_restore() must happen before the "reset $@" item of the save
    * stack is processed, as uplevel was called after the localization.
    * Andrew's change to how $@ was treated, which were mainly integrated
    * between perl 5.13.0 and 5.13.1, fixed this. */
   if (ERRSV && SvTRUE(ERRSV)) {
    register const PERL_CONTEXT *cx = cxstack + i; /* This is the eval scope */
    SV *errsv = SvREFCNT_inc(ERRSV);
    PL_scopestack_ix = cx->blk_oldscopesp;
    leave_scope(PL_scopestack[PL_scopestack_ix]);
    sv_setsv(ERRSV, errsv);
    SvREFCNT_dec(errsv);
   }
#endif
  }
 }

 SU_UPLEVEL_RESTORE(curcop);

 SvREFCNT_dec(sud->target);

 PL_stack_base = AvARRAY(cur->si_stack);
 PL_stack_sp   = PL_stack_base + AvFILLp(cur->si_stack);
 PL_stack_max  = PL_stack_base + AvMAX(cur->si_stack);

#if SU_HAS_PERL(5, 8, 0)
 if (MY_CXT.uplevel_storage.count >= SU_UPLEVEL_STORAGE_SIZE) {
  /* When an exception is thrown from the uplevel'd subroutine,
   * su_uplevel_restore() may be called by the LEAVE in die_unwind() (called
   * die_where() in more recent perls), which has the sad habit of keeping a
   * pointer to the current context frame across this call. This means that
   * we can't free the temporary context stack we used for the uplevel call
   * right now, or that pointer upwards would point to garbage. We work around
   * this by attaching the state data to a scalar that will be freed "soon".
   * This issue has been fixed in perl with commit 8f89e5a9. */
  SV *sv = sv_newmortal();
  sv_magicext(sv, NULL, PERL_MAGIC_ext, &su_uplevel_restore_vtbl,
                        (const char *) sud, 0);
 } else {
#endif
  sud->next = MY_CXT.uplevel_storage.root;
  MY_CXT.uplevel_storage.root = sud;
  MY_CXT.uplevel_storage.count++;
#if SU_HAS_PERL(5, 8, 0)
 }
#endif

 return;
}

STATIC CV *su_cv_clone(pTHX_ CV *old_cv) {
#define su_cv_clone(C) su_cv_clone(aTHX_ (C))
 CV *new_cv;

 /* Starting from commit b5c19bd7, cv_clone() has an assert that checks whether
  * CvDEPTH(CvOUTSIDE(proto)) > 0, so we have to fool cv_clone() with a little
  * dance. */
#if defined(DEBUGGING) && SU_HAS_PERL(5, 9, 0)
 I32 old_depth;
 CV *outside = CvOUTSIDE(old_cv);

 if (outside && CvCLONE(outside) && !CvCLONED(outside))
  outside = find_runcv(NULL);
 old_depth = CvDEPTH(outside);
 if (!old_depth)
  CvDEPTH(outside) = 1;
#endif

 new_cv = cv_clone(old_cv);

#if defined(DEBUGGING) && SU_HAS_PERL(5, 9, 0)
 CvDEPTH(outside) = old_depth;
#endif

 /* Starting from perl 5.9 (more exactly commit b5c19bd7), cv_clone() is no
  * longer able to clone named subs propery. With this commit, pad_findlex()
  * stores the parent index of a fake pad entry in the NV slot of the
  * corresponding pad name SV, but only for anonymous subs (since named subs
  * aren't supposed to be cloned in pure Perl land). To fix this, we just
  * manually relink the new fake pad entries to the new ones.
  * For some reason perl 5.8 crashes too without this, supposedly because of
  * other closure bugs. Hence we enable it everywhere. */
 if (!CvCLONE(old_cv)) {
  const AV  *old_padname = (const AV *)  AvARRAY(CvPADLIST(old_cv))[0];
  AV        *old_pad     = (AV *)        AvARRAY(CvPADLIST(old_cv))[1];
  AV        *new_pad     = (AV *)        AvARRAY(CvPADLIST(new_cv))[1];
  const SV **old_aryname = (const SV **) AvARRAY(old_padname);
  SV       **old_ary     = AvARRAY(old_pad);
  SV       **new_ary     = AvARRAY(new_pad);
  I32 fname = AvFILLp(old_padname);
  I32 fpad  = AvFILLp(old_pad);
  I32 ix;

  for (ix = fpad; ix > 0; ix--) {
   const SV *namesv = (ix <= fname) ? old_aryname[ix] : NULL;

   if (namesv && namesv != &PL_sv_undef && SvFAKE(namesv)) {
    SvREFCNT_dec(new_ary[ix]);
    new_ary[ix] = SvREFCNT_inc(old_ary[ix]);
   }
  }
 }

 return new_cv;
}

STATIC I32 su_uplevel(pTHX_ CV *cv, I32 cxix, I32 args) {
#define su_uplevel(C, I, A) su_uplevel(aTHX_ (C), (I), (A))
 su_uplevel_ud *sud;
 const PERL_CONTEXT *cx = cxstack + cxix;
 PERL_SI *si;
 PERL_SI *cur = PL_curstackinfo;
 SV **old_stack_sp;
 CV  *target_cv;
 UNOP sub_op;
 I32  marksize;
 I32  gimme;
 I32  old_mark, new_mark;
 I32  ret;
 dSP;
 dMY_CXT;

 ENTER;

 gimme = GIMME_V;
 /* Make PL_stack_sp point just before the CV. */
 PL_stack_sp -= args + 1;
 old_mark = AvFILLp(PL_curstack) = PL_stack_sp - PL_stack_base;
 SPAGAIN;

 sud = MY_CXT.uplevel_storage.root;
 if (sud) {
  MY_CXT.uplevel_storage.root = sud->next;
  MY_CXT.uplevel_storage.count--;
 } else {
  sud = su_uplevel_ud_new();
 }
 si = sud->si;

 sud->cxix = cxix;
 sud->died = 1;
 SAVEDESTRUCTOR_X(su_uplevel_restore, sud);

 si->si_type = cur->si_type;
 si->si_next = NULL;
 si->si_prev = cur->si_prev;

 /* Allocate enough space for all the elements of the original stack up to the
  * target context, plus the forthcoming arguments. */
 new_mark = cx->blk_oldsp;
 av_extend(si->si_stack, new_mark + 1 + args + 1);
 Copy(PL_curstack, AvARRAY(si->si_stack), new_mark + 1, SV *);
 AvFILLp(si->si_stack) = new_mark;
 SU_POISON(AvARRAY(si->si_stack) + new_mark + 1, args + 1, SV *);

 /* Specialized SWITCHSTACK() */
 PL_stack_base = AvARRAY(si->si_stack);
 old_stack_sp  = PL_stack_sp;
 PL_stack_sp   = PL_stack_base + AvFILLp(si->si_stack);
 PL_stack_max  = PL_stack_base + AvMAX(si->si_stack);
 SPAGAIN;

#ifdef DEBUGGING
 si->si_markoff = cx->blk_oldmarksp;
#endif

 /* Copy the context stack up to the context just below the target. */
 si->si_cxix  = (cxix < 0) ? -1 : (cxix - 1);
 /* The max size must be at least two so that GROW(max) = (max * 3) / 2 > max */
 si->si_cxmax = (cxix < 4) ?  4 : cxix;
 Renew(si->si_cxstack, si->si_cxmax + 1,     PERL_CONTEXT);
 Copy(cur->si_cxstack, si->si_cxstack, cxix, PERL_CONTEXT);
 SU_POISON(si->si_cxstack + cxix, si->si_cxmax + 1 - cxix, PERL_CONTEXT);

 target_cv      = cx->blk_sub.cv;
 sud->target    = (CV *) SvREFCNT_inc(target_cv);
 sud->old_depth = CvDEPTH(target_cv);

 /* blk_oldcop is essentially needed for caller() and stack traces. It has no
  * run-time implication, since PL_curcop will be overwritten as soon as we
  * enter a sub (a sub starts by a nextstate/dbstate). Hence it's safe to just
  * make it point to the blk_oldcop for the target frame, so that caller()
  * reports the right file name, line number and lexical hints. */
 SU_UPLEVEL_SAVE(curcop, cx->blk_oldcop);
 /* Don't reset PL_markstack_ptr, or we would overwrite the mark stack below
  * this point. */
 /* Don't reset PL_curpm, we want the most recent matches. */

 SU_UPLEVEL_SAVE(curstackinfo, si);
 /* If those two are equal, we need to fool POPSTACK_TO() */
 if (PL_mainstack == PL_curstack)
  SU_UPLEVEL_SAVE(mainstack, si->si_stack);
 else
  sud->old_mainstack = NULL;
 PL_curstack = si->si_stack;

 cv = su_cv_clone(cv);
 sud->cloned_cv = cv;
 CvGV_set(cv, CvGV(target_cv));

 PUSHMARK(SP);
 /* Both SP and old_stack_sp points just before the CV. */
 Copy(old_stack_sp + 2, SP + 1, args, SV *);
 SP += args;
 PUSHs((SV *) cv);
 PUTBACK;

 Zero(&sub_op, 1, UNOP);
 sub_op.op_type  = OP_ENTERSUB;
 sub_op.op_next  = NULL;
 sub_op.op_flags = OP_GIMME_REVERSE(gimme) | OPf_STACKED;
 if (PL_DBsub)
  sub_op.op_flags |= OPpENTERSUB_DB;

 SU_UPLEVEL_SAVE(op, (OP *) &sub_op);

 sud->old_catch = CATCH_GET;
 CATCH_SET(TRUE);

 if (PL_op = PL_ppaddr[OP_ENTERSUB](aTHX)) {
  if (CxHASARGS(cx) && cx->blk_sub.argarray) {
   /* The call to pp_entersub() has saved the current @_ (in XS terms,
    * GvAV(PL_defgv)) in the savearray member, and has created a new argarray
    * with what we put on the stack. But we want to fake up the same arguments
    * as the ones in use at the context we uplevel to, so we replace the
    * argarray with an unreal copy of the original @_. */
   AV *av = newAV();
   AvREAL_off(av);
   av_extend(av, AvMAX(cx->blk_sub.argarray));
   AvFILLp(av) = AvFILLp(cx->blk_sub.argarray);
   Copy(AvARRAY(cx->blk_sub.argarray), AvARRAY(av), AvFILLp(av) + 1, SV *);
   cxstack[cxix].blk_sub.argarray = av;
  } else {
   SvREFCNT_inc(cxstack[cxix].blk_sub.argarray);
  }

  CALLRUNOPS(aTHX);

  ret = PL_stack_sp - (PL_stack_base + new_mark);
 }

 sud->died = 0;

 SPAGAIN;

 if (ret > 0) {
  AV *old_stack = sud->old_curstackinfo->si_stack;

  if (old_mark + ret > AvMAX(old_stack)) {
   /* Specialized EXTEND(old_sp, ret) */
   av_extend(old_stack, old_mark + ret + 1);
   old_stack_sp = AvARRAY(old_stack) + old_mark;
  }

  Copy(PL_stack_sp - ret + 1, old_stack_sp + 1, ret, SV *);
  PL_stack_sp        += ret;
  AvFILLp(old_stack) += ret;
 }

 PUTBACK;

 LEAVE;

 return ret;
}

/* --- Interpreter setup/teardown ------------------------------------------ */

STATIC void su_teardown(pTHX_ void *param) {
 su_uplevel_ud *cur, *prev;
 dMY_CXT;

 cur = MY_CXT.uplevel_storage.root;
 if (cur) {
  su_uplevel_ud *prev;
  do {
   prev = cur;
   cur  = prev->next;
   su_uplevel_ud_delete(prev);
  } while (cur);
 }

 return;
}

STATIC void su_setup(pTHX) {
#define su_setup() su_setup(aTHX)
 MY_CXT_INIT;

 MY_CXT.stack_placeholder = NULL;

 /* NewOp() calls calloc() which just zeroes the memory with memset(). */
 Zero(&(MY_CXT.return_op), 1, sizeof(MY_CXT.return_op));
 MY_CXT.return_op.op_type   = OP_RETURN;
 MY_CXT.return_op.op_ppaddr = PL_ppaddr[OP_RETURN];

 Zero(&(MY_CXT.proxy_op), 1, sizeof(MY_CXT.proxy_op));
 MY_CXT.proxy_op.op_type   = OP_STUB;
 MY_CXT.proxy_op.op_ppaddr = NULL;

 MY_CXT.uplevel_storage.root  = NULL;
 MY_CXT.uplevel_storage.count = 0;

 call_atexit(su_teardown, NULL);

 return;
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

 stash = gv_stashpv(__PACKAGE__, 1);
 newCONSTSUB(stash, "TOP",           newSViv(0));
 newCONSTSUB(stash, "SU_THREADSAFE", newSVuv(SU_THREADSAFE));

 newXSproto("Scope::Upper::unwind", XS_Scope__Upper_unwind, file, NULL);

 su_setup();
}

#if SU_THREADSAFE

void
CLONE(...)
PROTOTYPE: DISABLE
PPCODE:
 {
  MY_CXT_CLONE;
  MY_CXT.uplevel_storage.root  = NULL;
  MY_CXT.uplevel_storage.count = 0;
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

void
uplevel(SV *code, ...)
PROTOTYPE: &@
PREINIT:
 I32 cxix, ret, args = 0;
PPCODE:
 if (SvROK(code))
  code = SvRV(code);
 if (SvTYPE(code) < SVt_PVCV)
  croak("First argument to uplevel must be a code reference");
 SU_GET_CONTEXT(1, items - 1);
 do {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   case CXt_EVAL:
    croak("Can't uplevel to an eval frame");
   case CXt_FORMAT:
    croak("Can't uplevel to a format frame");
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
    if (items > 1) {
     PL_stack_sp--;
     args = items - 2;
    }
    ret = su_uplevel((CV *) code, cxix, args);
    XSRETURN(ret);
   default:
    break;
  }
 } while (--cxix >= 0);
 croak("Can't uplevel outside a subroutine");
