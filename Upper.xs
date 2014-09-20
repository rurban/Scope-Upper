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

#ifndef dVAR
# define dVAR dNOOP
#endif

#ifndef MUTABLE_SV
# define MUTABLE_SV(S) ((SV *) (S))
#endif

#ifndef MUTABLE_AV
# define MUTABLE_AV(A) ((AV *) (A))
#endif

#ifndef MUTABLE_CV
# define MUTABLE_CV(C) ((CV *) (C))
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

#ifndef newSV_type
STATIC SV *su_newSV_type(pTHX_ svtype t) {
 SV *sv = newSV(0);
 SvUPGRADE(sv, t);
 return sv;
}
# define newSV_type(T) su_newSV_type(aTHX_ (T))
#endif

#ifdef newSVpvn_flags
# define su_newmortal_pvn(S, L) newSVpvn_flags((S), (L), SVs_TEMP)
#else
# define su_newmortal_pvn(S, L) sv_2mortal(newSVpvn((S), (L)))
#endif
#define su_newmortal_pvs(S) su_newmortal_pvn((S), sizeof(S)-1)

#ifndef SvPV_const
# define SvPV_const(S, L) SvPV(S, L)
#endif

#ifndef SvPVX_const
# define SvPVX_const(S) SvPVX(S)
#endif

#ifndef SvPV_nolen_const
# define SvPV_nolen_const(S) SvPV_nolen(S)
#endif

#ifndef SvREFCNT_inc_simple_void
# define SvREFCNT_inc_simple_void(sv) ((void) SvREFCNT_inc(sv))
#endif

#ifndef mPUSHi
# define mPUSHi(I) PUSHs(sv_2mortal(newSViv(I)))
#endif

#ifndef GvCV_set
# define GvCV_set(G, C) (GvCV(G) = (C))
#endif

#ifndef CvGV_set
# define CvGV_set(C, G) (CvGV(C) = (G))
#endif

#ifndef CvSTASH_set
# define CvSTASH_set(C, S) (CvSTASH(C) = (S))
#endif

#ifndef CvISXSUB
# define CvISXSUB(C) CvXSUB(C)
#endif

#ifndef PadlistARRAY
# define PadlistARRAY(P) AvARRAY(P)
# define PadARRAY(P)     AvARRAY(P)
#endif

#ifndef CxHASARGS
# define CxHASARGS(C) ((C)->blk_sub.hasargs)
#endif

#ifndef CxGIMME
# ifdef G_WANT
#  define CxGIMME(C) ((C)->blk_gimme & G_WANT)
# else
#  define CxGIMME(C) ((C)->blk_gimme)
# endif
#endif

#ifndef CxOLD_OP_TYPE
# define CxOLD_OP_TYPE(C) (C)->blk_eval.old_op_type
#endif

#ifndef OutCopFILE
# define OutCopFILE(C) CopFILE(C)
#endif

#ifndef OutCopFILE_len
# define OutCopFILE_len(C) strlen(OutCopFILE(C))
#endif

#ifndef CopHINTS_get
# define CopHINTS_get(C) ((I32) (C)->op_private & HINT_PRIVATE_MASK)
#endif

#ifndef CopHINTHASH_get
# define CopHINTHASH_get(C) (C)->cop_hints_hash
#endif

#ifndef cophh_2hv
# define COPHH           struct refcounted_he
# define cophh_2hv(H, F) Perl_refcounted_he_chain_2hv(aTHX_ (H))
#endif

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef HvNAMELEN
# define HvNAMELEN(H) strlen(HvNAME(H))
#endif

#ifndef gv_fetchpvn_flags
# define gv_fetchpvn_flags(A, B, C, D) gv_fetchpv((A), (C), (D))
#endif

#ifndef hv_fetchs
# define hv_fetchs(H, K, L) hv_fetch((H), (K), sizeof(K)-1, (L))
#endif

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

#ifndef OP_SIBLING
# define OP_SIBLING(O) ((O)->op_sibling)
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

/* --- Unique context ID global storage ------------------------------------ */

/* ... Sequence ID counter ................................................. */

typedef struct {
 UV     *seqs;
 STRLEN  size;
} su_uv_array;

STATIC su_uv_array su_uid_seq_counter;

#ifdef USE_ITHREADS

STATIC perl_mutex su_uid_seq_counter_mutex;

#define SU_LOCK(M)   MUTEX_LOCK(M)
#define SU_UNLOCK(M) MUTEX_UNLOCK(M)

#else /* USE_ITHREADS */

#define SU_LOCK(M)
#define SU_UNLOCK(M)

#endif /* !USE_ITHREADS */

STATIC UV su_uid_seq_next(pTHX_ UV depth) {
#define su_uid_seq_next(D) su_uid_seq_next(aTHX_ (D))
 UV seq;
 UV *seqs;

 SU_LOCK(&su_uid_seq_counter_mutex);

 seqs = su_uid_seq_counter.seqs;

 if (depth >= su_uid_seq_counter.size) {
  UV i;

  seqs = PerlMemShared_realloc(seqs, (depth + 1) * sizeof(UV));
  for (i = su_uid_seq_counter.size; i <= depth; ++i)
   seqs[i] = 0;

  su_uid_seq_counter.seqs = seqs;
  su_uid_seq_counter.size = depth + 1;
 }

 seq = ++seqs[depth];

 SU_UNLOCK(&su_uid_seq_counter_mutex);

 return seq;
}

/* ... UID storage ......................................................... */

typedef struct {
 UV  seq;
 U32 flags;
} su_uid;

#define SU_UID_ACTIVE 1

STATIC UV su_uid_depth(pTHX_ I32 cxix) {
#define su_uid_depth(I) su_uid_depth(aTHX_ (I))
 const PERL_SI *si;
 UV depth;

 depth = cxix;
 for (si = PL_curstackinfo->si_prev; si; si = si->si_prev)
  depth += si->si_cxix + 1;

 return depth;
}

typedef struct {
 su_uid **map;
 STRLEN   used;
 STRLEN   alloc;
} su_uid_storage;

STATIC void su_uid_storage_dup(pTHX_ su_uid_storage *new_cxt, const su_uid_storage *old_cxt, UV max_depth) {
#define su_uid_storage_dup(N, O, D) su_uid_storage_dup(aTHX_ (N), (O), (D))
 su_uid **old_map = old_cxt->map;

 if (old_map) {
  su_uid **new_map = new_cxt->map;
  STRLEN old_used  = old_cxt->used;
  STRLEN new_used, new_alloc;
  STRLEN i;

  new_used = max_depth < old_used ? max_depth : old_used;
  new_cxt->used = new_used;

  if (new_used <= new_cxt->alloc)
   new_alloc = new_cxt->alloc;
  else {
   new_alloc = new_used;
   Renew(new_map, new_alloc, su_uid *);
   for (i = new_cxt->alloc; i < new_alloc; ++i)
    new_map[i] = NULL;
   new_cxt->map   = new_map;
   new_cxt->alloc = new_alloc;
  }

  for (i = 0; i < new_alloc; ++i) {
   su_uid *new_uid = new_map[i];

   if (i < new_used) { /* => i < max_depth && i < old_used */
    su_uid *old_uid = old_map[i];

    if (old_uid && (old_uid->flags & SU_UID_ACTIVE)) {
     if (!new_uid) {
      Newx(new_uid, 1, su_uid);
      new_map[i] = new_uid;
     }
     *new_uid = *old_uid;
     continue;
    }
   }

   if (new_uid)
    new_uid->flags &= ~SU_UID_ACTIVE;
  }
 }

 return;
}

/* --- unwind() global storage --------------------------------------------- */

typedef struct {
 I32      cxix;
 I32      items;
 SV     **savesp;
 LISTOP   return_op;
 OP       proxy_op;
} su_unwind_storage;

/* --- yield() global storage ---------------------------------------------- */

typedef struct {
 I32      cxix;
 I32      items;
 SV     **savesp;
 UNOP     leave_op;
 OP       proxy_op;
} su_yield_storage;

/* --- uplevel() data tokens and global storage ---------------------------- */

#define SU_UPLEVEL_HIJACKS_RUNOPS SU_HAS_PERL(5, 8, 0)

typedef struct {
 void          *next;

 su_uid_storage tmp_uid_storage;
 su_uid_storage old_uid_storage;

 I32            cxix;

 I32            target_depth;
 CV            *target;

 CV            *callback;
 CV            *renamed;

 PERL_SI       *si;
 PERL_SI       *old_curstackinfo;
 AV            *old_mainstack;

 COP           *old_curcop;

 OP            *old_op;
#if SU_UPLEVEL_HIJACKS_RUNOPS
 runops_proc_t  old_runops;
#endif
 bool           old_catch;

 bool           died;
} su_uplevel_ud;

STATIC su_uplevel_ud *su_uplevel_ud_new(pTHX) {
#define su_uplevel_ud_new() su_uplevel_ud_new(aTHX)
 su_uplevel_ud *sud;
 PERL_SI       *si;

 Newx(sud, 1, su_uplevel_ud);
 sud->next = NULL;

 sud->tmp_uid_storage.map   = NULL;
 sud->tmp_uid_storage.used  = 0;
 sud->tmp_uid_storage.alloc = 0;

 Newx(si, 1, PERL_SI);
 si->si_stack   = newAV();
 AvREAL_off(si->si_stack);
 si->si_cxstack = NULL;
 si->si_cxmax   = 0;

 sud->si = si;

 return sud;
}

STATIC void su_uplevel_ud_delete(pTHX_ su_uplevel_ud *sud) {
#define su_uplevel_ud_delete(S) su_uplevel_ud_delete(aTHX_ (S))
 PERL_SI *si = sud->si;

 Safefree(si->si_cxstack);
 SvREFCNT_dec(si->si_stack);
 Safefree(si);

 if (sud->tmp_uid_storage.map) {
  su_uid **map   = sud->tmp_uid_storage.map;
  STRLEN   alloc = sud->tmp_uid_storage.alloc;
  STRLEN   i;

  for (i = 0; i < alloc; ++i)
   Safefree(map[i]);

  Safefree(map);
 }

 Safefree(sud);

 return;
}

typedef struct {
 su_uplevel_ud *top;
 su_uplevel_ud *root;
 I32            count;
} su_uplevel_storage;

#ifndef SU_UPLEVEL_STORAGE_SIZE
# define SU_UPLEVEL_STORAGE_SIZE 4
#endif

/* --- Global data --------------------------------------------------------- */

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
 char               *stack_placeholder;
 su_unwind_storage   unwind_storage;
 su_yield_storage    yield_storage;
 su_uplevel_storage  uplevel_storage;
 su_uid_storage      uid_storage;
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

#define SU_SAVE_LAST_CX (!SU_HAS_PERL(5, 8, 4) || (SU_HAS_PERL(5, 9, 5) && !SU_HAS_PERL(5, 14, 0)) || SU_HAS_PERL(5, 15, 0))

typedef struct {
 su_ud_common ci;
 SV *cb;
} su_ud_reap;

STATIC void su_call(pTHX_ void *ud_) {
 su_ud_reap *ud = (su_ud_reap *) ud_;
#if SU_SAVE_LAST_CX
 I32 cxix;
 PERL_CONTEXT saved_cx;
#endif /* SU_SAVE_LAST_CX */

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

#if SU_SAVE_LAST_CX
 /* If the recently popped context isn't saved there, it will be overwritten by
  * the sub scope from call_sv, although it's still needed in our caller. */
 cxix     = (cxstack_ix < cxstack_max) ? (cxstack_ix + 1) : Perl_cxinc(aTHX);
 saved_cx = cxstack[cxix];
#endif /* SU_SAVE_LAST_CX */

 call_sv(ud->cb, G_VOID);

#if SU_SAVE_LAST_CX
 cxstack[cxix] = saved_cx;
#endif /* SU_SAVE_LAST_CX */

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

#if SU_DEBUG && defined(DEBUGGING)
# define SU_CXNAME(C) PL_block_type[CxTYPE(C)]
#else
# define SU_CXNAME(C) "XXX"
#endif

STATIC void su_pop(pTHX_ void *ud) {
#define su_pop(U) su_pop(aTHX_ (U))
 I32 depth, base, mark, *origin;
 depth = SU_UD_DEPTH(ud);

 SU_D(
  PerlIO_printf(Perl_debug_log,
   "%p: --- pop a %s\n"
   "%p: leave scope     at depth=%2d scope_ix=%2d cur_top=%2d cur_base=%2d\n",
    ud, SU_CXNAME(cxstack + cxstack_ix),
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
 I32 cxix  = MY_CXT.unwind_storage.cxix;
 I32 items = MY_CXT.unwind_storage.items;
 I32 mark;

 PERL_UNUSED_VAR(ud_);

 PL_stack_sp = MY_CXT.unwind_storage.savesp;
#if SU_HAS_PERL(5, 19, 4)
 {
  I32 i;
  SV **sp = PL_stack_sp;
  for (i = -items + 1; i <= 0; ++i)
   if (!SvTEMP(sp[i]))
    sv_2mortal(SvREFCNT_inc(sp[i]));
 }
#endif

 if (cxstack_ix > cxix)
  dounwind(cxix);

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

 PL_op = (OP *) &(MY_CXT.unwind_storage.return_op);
 PL_op = PL_op->op_ppaddr(aTHX);

 *PL_markstack_ptr = mark;

 MY_CXT.unwind_storage.proxy_op.op_next = PL_op;
 PL_op = &(MY_CXT.unwind_storage.proxy_op);
}

/* --- Yield --------------------------------------------------------------- */

#if SU_HAS_PERL(5, 10, 0)
# define SU_RETOP_SUB(C)   ((C)->blk_sub.retop)
# define SU_RETOP_EVAL(C)  ((C)->blk_eval.retop)
# define SU_RETOP_LOOP(C)  ((C)->blk_loop.my_op->op_lastop->op_next)
# define SU_RETOP_GIVEN(C) ((C)->blk_givwhen.leave_op->op_next)
#else
# define SU_RETOP_SUB(C)  ((C)->blk_oldretsp > 0 ? PL_retstack[(C)->blk_oldretsp - 1] : NULL)
# define SU_RETOP_EVAL(C) SU_RETOP_SUB(C)
# define SU_RETOP_LOOP(C) ((C)->blk_loop.last_op->op_next)
#endif

STATIC void su_yield(pTHX_ void *ud_) {
 dMY_CXT;
 PERL_CONTEXT *cx;
 const char   *which = ud_;
 I32 cxix      = MY_CXT.yield_storage.cxix;
 I32 items     = MY_CXT.yield_storage.items;
 opcode  type  = OP_NULL;
 U8      flags = 0;
 OP     *next;

 PERL_UNUSED_VAR(ud_);

 cx = cxstack + cxix;
 switch (CxTYPE(cx)) {
  case CXt_BLOCK: {
   I32 i, cur = cxstack_ix, n = 1;
   OP *o = NULL;
   /* Is this actually a given/when block? This may occur only when yield was
    * called with HERE (or nothing) as the context. */
#if SU_HAS_PERL(5, 10, 0)
   if (cxix > 0) {
    PERL_CONTEXT *prev = cx - 1;
    U8 type = CxTYPE(prev);
    if ((type == CXt_GIVEN || type == CXt_WHEN)
        && (prev->blk_oldcop == cx->blk_oldcop)) {
     cxix--;
     cx = prev;
     if (type == CXt_GIVEN)
      goto cxt_given;
     else
      goto cxt_when;
    }
   }
#endif
   type  = OP_LEAVE;
   next  = NULL;
   /* Bare blocks (that appear as do { ... } blocks, map { ... } blocks or
    * constant folded blcoks) don't need to save the op to return to anywhere
    * since 'last' isn't supposed to work inside them. So we climb higher in
    * the context stack until we reach a context that has a return op (i.e. a
    * sub, an eval, a format or a real loop), recording how many blocks we
    * crossed. Then we follow the op_next chain until we get to the leave op
    * that closes the original block, which we are assured to reach since
    * everything is static (the blocks we have crossed cannot be evals or
    * subroutine calls). */
   for (i = cxix + 1; i <= cur; ++i) {
    PERL_CONTEXT *cx2 = cxstack + i;
    switch (CxTYPE(cx2)) {
     case CXt_BLOCK:
      ++n;
      break;
     case CXt_SUB:
     case CXt_FORMAT:
      o = SU_RETOP_SUB(cx2);
      break;
     case CXt_EVAL:
      o = SU_RETOP_EVAL(cx2);
      break;
#if SU_HAS_PERL(5, 11, 0)
     case CXt_LOOP_FOR:
     case CXt_LOOP_PLAIN:
     case CXt_LOOP_LAZYSV:
     case CXt_LOOP_LAZYIV:
#else
     case CXt_LOOP:
#endif
      o = SU_RETOP_LOOP(cx2);
      break;
    }
    if (o)
     break;
   }
   if (!o)
    o = PL_op;
   while (n && o) {
    /* We may find other enter/leave blocks on our way to the matching leave.
     * Make sure the depth is incremented/decremented appropriately. */
    if (o->op_type == OP_ENTER) {
     ++n;
    } else if (o->op_type == OP_LEAVE) {
     --n;
     if (!n) {
      next = o->op_next;
      break;
     }
    }
    o = o->op_next;
   }
   break;
  }
  case CXt_SUB:
  case CXt_FORMAT:
   type = OP_LEAVESUB;
   next = SU_RETOP_SUB(cx);
   break;
  case CXt_EVAL:
   type = CxTRYBLOCK(cx) ? OP_LEAVETRY : OP_LEAVEEVAL;
   next = SU_RETOP_EVAL(cx);
   break;
#if SU_HAS_PERL(5, 11, 0)
  case CXt_LOOP_FOR:
  case CXt_LOOP_PLAIN:
  case CXt_LOOP_LAZYSV:
  case CXt_LOOP_LAZYIV:
#else
  case CXt_LOOP:
#endif
   type = OP_LEAVELOOP;
   next = SU_RETOP_LOOP(cx);
   break;
#if SU_HAS_PERL(5, 10, 0)
  case CXt_GIVEN:
cxt_given:
   type = OP_LEAVEGIVEN;
   next = SU_RETOP_GIVEN(cx);
   break;
  case CXt_WHEN:
cxt_when:
#if SU_HAS_PERL(5, 15, 1)
   type   = OP_LEAVEWHEN;
#else
   type   = OP_BREAK;
   flags |= OPf_SPECIAL;
#endif
   next   = NULL;
   break;
#endif
  case CXt_SUBST:
   croak("%s() can't target a substitution context", which);
   break;
  default:
   croak("%s() doesn't know how to leave a %s context",
          which,                         SU_CXNAME(cxstack + cxix));
   break;
 }

 PL_stack_sp = MY_CXT.yield_storage.savesp;
#if SU_HAS_PERL(5, 19, 4)
 {
  I32 i;
  SV **sp = PL_stack_sp;
  for (i = -items + 1; i <= 0; ++i)
   if (!SvTEMP(sp[i]))
    sv_2mortal(SvREFCNT_inc(sp[i]));
 }
#endif

 if (cxstack_ix > cxix)
  dounwind(cxix);

 /* Copy the arguments passed to yield() where the leave op expects to find
  * them. */
 if (items)
  Move(PL_stack_sp - items + 1, PL_stack_base + cx->blk_oldsp + 1, items, SV *);
 PL_stack_sp = PL_stack_base + cx->blk_oldsp + items;

 flags |= OP_GIMME_REVERSE(cx->blk_gimme);

 MY_CXT.yield_storage.leave_op.op_type   = type;
 MY_CXT.yield_storage.leave_op.op_ppaddr = PL_ppaddr[type];
 MY_CXT.yield_storage.leave_op.op_flags  = flags;
 MY_CXT.yield_storage.leave_op.op_next   = next;

 PL_op = (OP *) &(MY_CXT.yield_storage.leave_op);
 PL_op = PL_op->op_ppaddr(aTHX);

 MY_CXT.yield_storage.proxy_op.op_next = PL_op;
 PL_op = &(MY_CXT.yield_storage.proxy_op);
}

/* --- Uplevel ------------------------------------------------------------- */

#define SU_UPLEVEL_SAVE(f, t) STMT_START { sud->old_##f = PL_##f; PL_##f = (t); } STMT_END
#define SU_UPLEVEL_RESTORE(f) STMT_START { PL_##f = sud->old_##f; } STMT_END

STATIC su_uplevel_ud *su_uplevel_storage_new(pTHX_ I32 cxix) {
#define su_uplevel_storage_new(I) su_uplevel_storage_new(aTHX_ (I))
 su_uplevel_ud *sud;
 UV depth;
 dMY_CXT;

 sud = MY_CXT.uplevel_storage.root;
 if (sud) {
  MY_CXT.uplevel_storage.root = sud->next;
  MY_CXT.uplevel_storage.count--;
 } else {
  sud = su_uplevel_ud_new();
 }

 sud->next = MY_CXT.uplevel_storage.top;
 MY_CXT.uplevel_storage.top = sud;

 depth = su_uid_depth(cxix);
 su_uid_storage_dup(&sud->tmp_uid_storage, &MY_CXT.uid_storage, depth);
 sud->old_uid_storage = MY_CXT.uid_storage;
 MY_CXT.uid_storage   = sud->tmp_uid_storage;

 return sud;
}

STATIC void su_uplevel_storage_delete(pTHX_ su_uplevel_ud *sud) {
#define su_uplevel_storage_delete(S) su_uplevel_storage_delete(aTHX_ (S))
 dMY_CXT;

 sud->tmp_uid_storage = MY_CXT.uid_storage;
 MY_CXT.uid_storage   = sud->old_uid_storage;
 {
  su_uid **map;
  UV  i, alloc;
  map   = sud->tmp_uid_storage.map;
  alloc = sud->tmp_uid_storage.alloc;
  for (i = 0; i < alloc; ++i) {
   if (map[i])
    map[i]->flags &= SU_UID_ACTIVE;
  }
 }
 MY_CXT.uplevel_storage.top = sud->next;

 if (MY_CXT.uplevel_storage.count >= SU_UPLEVEL_STORAGE_SIZE) {
  su_uplevel_ud_delete(sud);
 } else {
  sud->next = MY_CXT.uplevel_storage.root;
  MY_CXT.uplevel_storage.root = sud;
  MY_CXT.uplevel_storage.count++;
 }
}

STATIC int su_uplevel_goto_static(const OP *o) {
 for (; o; o = OP_SIBLING(o)) {
  /* goto ops are unops with kids. */
  if (!(o->op_flags & OPf_KIDS))
   continue;

  switch (o->op_type) {
   case OP_LEAVEEVAL:
   case OP_LEAVETRY:
    /* Don't care about gotos inside eval, as they are forbidden at run time. */
    break;
   case OP_GOTO:
    return 1;
   default:
    if (su_uplevel_goto_static(((const UNOP *) o)->op_first))
     return 1;
    break;
  }
 }

 return 0;
}

#if SU_UPLEVEL_HIJACKS_RUNOPS

STATIC int su_uplevel_goto_runops(pTHX) {
#define su_uplevel_goto_runops() su_uplevel_goto_runops(aTHX)
 register OP *op;
 dVAR;

 op = PL_op;
 do {
  if (op->op_type == OP_GOTO) {
   AV  *argarray = NULL;
   I32  cxix;

   for (cxix = cxstack_ix; cxix >= 0; --cxix) {
    const PERL_CONTEXT *cx = cxstack + cxix;

    switch (CxTYPE(cx)) {
     case CXt_SUB:
      if (CxHASARGS(cx)) {
       argarray = cx->blk_sub.argarray;
       goto done;
      }
      break;
     case CXt_EVAL:
     case CXt_FORMAT:
      goto done;
     default:
      break;
    }
   }

done:
   if (argarray) {
    dMY_CXT;

    if (MY_CXT.uplevel_storage.top->cxix == cxix) {
     AV  *args  = GvAV(PL_defgv);
     I32  items = AvFILLp(args);

     av_extend(argarray, items);
     Copy(AvARRAY(args), AvARRAY(argarray), items + 1, SV *);
     AvFILLp(argarray) = items;
    }
   }
  }

  PL_op = op = op->op_ppaddr(aTHX);

#if !SU_HAS_PERL(5, 13, 0)
  PERL_ASYNC_CHECK();
#endif
 } while (op);

 TAINT_NOT;

 return 0;
}

#endif /* SU_UPLEVEL_HIJACKS_RUNOPS */

#define su_at_underscore(C) PadARRAY(PadlistARRAY(CvPADLIST(C))[CvDEPTH(C)])[0]

STATIC void su_uplevel_restore(pTHX_ void *sus_) {
 su_uplevel_ud *sud = sus_;
 PERL_SI *cur = sud->old_curstackinfo;
 PERL_SI *si  = sud->si;

#if SU_UPLEVEL_HIJACKS_RUNOPS
 if (PL_runops == su_uplevel_goto_runops)
  PL_runops = sud->old_runops;
#endif

 if (sud->callback) {
  PERL_CONTEXT *cx = cxstack + sud->cxix;
  AV     *argarray = MUTABLE_AV(su_at_underscore(sud->callback));

  /* We have to fix the pad entry for @_ in the original callback because it
   * may have been reified. */
  if (AvREAL(argarray)) {
   const I32 fill = AvFILLp(argarray);
   SvREFCNT_dec(argarray);
   argarray = newAV();
   AvREAL_off(argarray);
   AvREIFY_on(argarray);
   av_extend(argarray, fill);
   su_at_underscore(sud->callback) = MUTABLE_SV(argarray);
  } else {
   CLEAR_ARGARRAY(argarray);
  }

  /* If the old cv member is our renamed CV, it means that this place has been
   * reached without a goto() happening, and the old argarray member is
   * actually our fake argarray. Destroy it properly in that case. */
  if (cx->blk_sub.cv == sud->renamed) {
   SvREFCNT_dec(cx->blk_sub.argarray);
   cx->blk_sub.argarray = argarray;
  }

  CvDEPTH(sud->callback)--;
  SvREFCNT_dec(sud->callback);
 }

 /* Free the renamed CV. We must do it ourselves so that we can force the
  * depth to be 0, or perl would complain about it being "still in use".
  * But we *know* that it cannot be so. */
 if (sud->renamed) {
  CvDEPTH(sud->renamed)   = 0;
  CvPADLIST(sud->renamed) = NULL;
  SvREFCNT_dec(sud->renamed);
 }

 CATCH_SET(sud->old_catch);

 SU_UPLEVEL_RESTORE(op);

 /* stack_grow() wants PL_curstack so restore the old stack first */
 if (PL_curstackinfo == si) {
  PL_curstack = cur->si_stack;
  if (sud->old_mainstack)
   SU_UPLEVEL_RESTORE(mainstack);
  SU_UPLEVEL_RESTORE(curstackinfo);

  if (sud->died) {
   CV *target = sud->target;
   I32 levels = 0, i;

   /* When we die, the depth of the target CV is not updated because of the
    * stack switcheroo. So we have to look at all the frames between the
    * uplevel call and the catch block to count how many call frames to the
    * target CV were skipped. */
   for (i = cur->si_cxix; i > sud->cxix; i--) {
    register const PERL_CONTEXT *cx = cxstack + i;

    if (CxTYPE(cx) == CXt_SUB) {
     if (cx->blk_sub.cv == target)
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
      if (cx->blk_sub.cv == target)
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
   CvDEPTH(target) = sud->target_depth - levels;
   PL_curstackinfo->si_cxix = i - 1;

#if !SU_HAS_PERL(5, 13, 1)
   /* Since $@ was maybe localized between the target frame and the uplevel
    * call, we forcefully flush the save stack to get rid of it and then
    * reset $@ to its proper value. Note that the the call to
    * su_uplevel_restore() must happen before the "reset $@" item of the save
    * stack is processed, as uplevel was called after the localization.
    * Andrew's changes to how $@ was handled, which were mainly integrated
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

 /* When an exception is thrown from the uplevel'd subroutine,
  * su_uplevel_restore() may be called by the LEAVE in die_unwind() (renamed
  * die_where() in more recent perls), which has the sad habit of keeping a
  * pointer to the current context frame across this call. This means that we
  * can't free the temporary context stack we used for the uplevel call right
  * now, or that pointer upwards would point to garbage. */
#if SU_HAS_PERL(5, 13, 7)
 /* This issue has been fixed in perl with commit 8f89e5a9, which was made
  * public in perl 5.13.7. */
 su_uplevel_storage_delete(sud);
#else
 /* Otherwise, we just enqueue it back in the global storage list. */
 {
  dMY_CXT;

  sud->tmp_uid_storage = MY_CXT.uid_storage;
  MY_CXT.uid_storage   = sud->old_uid_storage;

  MY_CXT.uplevel_storage.top  = sud->next;
  sud->next = MY_CXT.uplevel_storage.root;
  MY_CXT.uplevel_storage.root = sud;
  MY_CXT.uplevel_storage.count++;
 }
#endif

 return;
}

STATIC CV *su_cv_clone(pTHX_ CV *proto, GV *gv) {
#define su_cv_clone(P, G) su_cv_clone(aTHX_ (P), (G))
 dVAR;
 CV *cv;

 cv = MUTABLE_CV(newSV_type(SvTYPE(proto)));

 CvFLAGS(cv)  = CvFLAGS(proto);
#ifdef CVf_CVGV_RC
 CvFLAGS(cv) &= ~CVf_CVGV_RC;
#endif
 CvDEPTH(cv)  = CvDEPTH(proto);
#ifdef USE_ITHREADS
 CvFILE(cv)   = CvISXSUB(proto) ? CvFILE(proto) : savepv(CvFILE(proto));
#else
 CvFILE(cv)   = CvFILE(proto);
#endif

 CvGV_set(cv, gv);
#if SU_RELEASE && SU_HAS_PERL_EXACT(5, 21, 4)
 CvNAMED_off(cv);
#endif
 CvSTASH_set(cv, CvSTASH(proto));
 /* Commit 4c74a7df, publicized with perl 5.13.3, began to add backrefs to
  * stashes. CvSTASH_set() started to do it as well with commit c68d95645
  * (which was part of perl 5.13.7). */
#if SU_HAS_PERL(5, 13, 3) && !SU_HAS_PERL(5, 13, 7)
 if (CvSTASH(proto))
  Perl_sv_add_backref(aTHX_ CvSTASH(proto), MUTABLE_SV(cv));
#endif

 if (CvISXSUB(proto)) {
  CvXSUB(cv)       = CvXSUB(proto);
  CvXSUBANY(cv)    = CvXSUBANY(proto);
 } else {
  OP_REFCNT_LOCK;
  CvROOT(cv)       = OpREFCNT_inc(CvROOT(proto));
  OP_REFCNT_UNLOCK;
  CvSTART(cv)      = CvSTART(proto);
 }
 CvOUTSIDE(cv)     = CvOUTSIDE(proto);
#ifdef CVf_WEAKOUTSIDE
 if (!(CvFLAGS(proto) & CVf_WEAKOUTSIDE))
#endif
  SvREFCNT_inc_simple_void(CvOUTSIDE(cv));
 CvPADLIST(cv)     = CvPADLIST(proto);
#ifdef CvOUTSIDE_SEQ
 CvOUTSIDE_SEQ(cv) = CvOUTSIDE_SEQ(proto);
#endif

 if (SvPOK(proto))
  sv_setpvn(MUTABLE_SV(cv), SvPVX_const(proto), SvCUR(proto));

#ifdef CvCONST
 if (CvCONST(cv))
  CvCONST_off(cv);
#endif

 return cv;
}

STATIC I32 su_uplevel(pTHX_ CV *callback, I32 cxix, I32 args) {
#define su_uplevel(C, I, A) su_uplevel(aTHX_ (C), (I), (A))
 su_uplevel_ud *sud;
 const PERL_CONTEXT *cx = cxstack + cxix;
 PERL_SI *si;
 PERL_SI *cur = PL_curstackinfo;
 SV **old_stack_sp;
 CV  *target;
 CV  *renamed;
 UNOP sub_op;
 I32  gimme;
 I32  old_mark, new_mark;
 I32  ret;
 dSP;

 ENTER;

 gimme = GIMME_V;
 /* Make PL_stack_sp point just before the CV. */
 PL_stack_sp -= args + 1;
 old_mark = AvFILLp(PL_curstack) = PL_stack_sp - PL_stack_base;
 SPAGAIN;

 sud = su_uplevel_storage_new(cxix);

 sud->cxix     = cxix;
 sud->died     = 1;
 sud->callback = NULL;
 sud->renamed  = NULL;
 SAVEDESTRUCTOR_X(su_uplevel_restore, sud);

 si = sud->si;

 si->si_type    = cur->si_type;
 si->si_next    = NULL;
 si->si_prev    = cur->si_prev;
#ifdef DEBUGGING
 si->si_markoff = cx->blk_oldmarksp;
#endif

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

 /* Copy the context stack up to the context just below the target. */
 si->si_cxix = (cxix < 0) ? -1 : (cxix - 1);
 if (si->si_cxmax < cxix) {
  /* The max size must be at least two so that GROW(max) = (max*3)/2 > max */
  si->si_cxmax = (cxix < 4) ? 4 : cxix;
  Renew(si->si_cxstack, si->si_cxmax + 1, PERL_CONTEXT);
 }
 Copy(cur->si_cxstack, si->si_cxstack, cxix, PERL_CONTEXT);
 SU_POISON(si->si_cxstack + cxix, si->si_cxmax + 1 - cxix, PERL_CONTEXT);

 target            = cx->blk_sub.cv;
 sud->target       = (CV *) SvREFCNT_inc(target);
 sud->target_depth = CvDEPTH(target);

 /* blk_oldcop is essentially needed for caller() and stack traces. It has no
  * run-time implication, since PL_curcop will be overwritten as soon as we
  * enter a sub (a sub starts by a nextstate/dbstate). Hence it's safe to just
  * make it point to the blk_oldcop for the target frame, so that caller()
  * reports the right file name, line number and lexical hints. */
 SU_UPLEVEL_SAVE(curcop, cx->blk_oldcop);
 /* Don't reset PL_markstack_ptr, or we would overwrite the mark stack below
  * this point. Don't reset PL_curpm either, we want the most recent matches. */

 SU_UPLEVEL_SAVE(curstackinfo, si);
 /* If those two are equal, we need to fool POPSTACK_TO() */
 if (PL_mainstack == PL_curstack)
  SU_UPLEVEL_SAVE(mainstack, si->si_stack);
 else
  sud->old_mainstack = NULL;
 PL_curstack = si->si_stack;

 renamed      = su_cv_clone(callback, CvGV(target));
 sud->renamed = renamed;

 PUSHMARK(SP);
 /* Both SP and old_stack_sp point just before the CV. */
 Copy(old_stack_sp + 2, SP + 1, args, SV *);
 SP += args;
 PUSHs((SV *) renamed);
 PUTBACK;

 Zero(&sub_op, 1, UNOP);
 sub_op.op_type  = OP_ENTERSUB;
 sub_op.op_next  = NULL;
 sub_op.op_flags = OP_GIMME_REVERSE(gimme) | OPf_STACKED;
 if (PL_DBsub)
  sub_op.op_flags |= OPpENTERSUB_DB;

 SU_UPLEVEL_SAVE(op, (OP *) &sub_op);

#if SU_UPLEVEL_HIJACKS_RUNOPS
 sud->old_runops = PL_runops;
#endif

 sud->old_catch = CATCH_GET;
 CATCH_SET(TRUE);

 if ((PL_op = PL_ppaddr[OP_ENTERSUB](aTHX))) {
  PERL_CONTEXT *sub_cx = cxstack + cxstack_ix;

  /* If pp_entersub() returns a non-null OP, it means that the callback is not
   * an XSUB. */

  sud->callback = MUTABLE_CV(SvREFCNT_inc(callback));
  CvDEPTH(callback)++;

  if (CxHASARGS(cx) && cx->blk_sub.argarray) {
   /* The call to pp_entersub() has saved the current @_ (in XS terms,
    * GvAV(PL_defgv)) in the savearray member, and has created a new argarray
    * with what we put on the stack. But we want to fake up the same arguments
    * as the ones in use at the context we uplevel to, so we replace the
    * argarray with an unreal copy of the original @_. */
   AV *av = newAV();
   AvREAL_off(av);
   AvREIFY_on(av);
   av_extend(av, AvMAX(cx->blk_sub.argarray));
   AvFILLp(av) = AvFILLp(cx->blk_sub.argarray);
   Copy(AvARRAY(cx->blk_sub.argarray), AvARRAY(av), AvFILLp(av) + 1, SV *);
   sub_cx->blk_sub.argarray = av;
  } else {
   SvREFCNT_inc_simple_void(sub_cx->blk_sub.argarray);
  }

  if (su_uplevel_goto_static(CvROOT(renamed))) {
#if SU_UPLEVEL_HIJACKS_RUNOPS
   if (PL_runops != PL_runops_std) {
    if (PL_runops == PL_runops_dbg) {
     if (PL_debug)
      croak("uplevel() can't execute code that calls goto when debugging flags are set");
    } else if (PL_runops != su_uplevel_goto_runops)
     croak("uplevel() can't execute code that calls goto with a custom runloop");
   }

   PL_runops = su_uplevel_goto_runops;
#else  /* SU_UPLEVEL_HIJACKS_RUNOPS */
   croak("uplevel() can't execute code that calls goto before perl 5.8");
#endif /* !SU_UPLEVEL_HIJACKS_RUNOPS */
  }

  CALLRUNOPS(aTHX);
 }

 sud->died = 0;

 ret = PL_stack_sp - (PL_stack_base + new_mark);
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

 LEAVE;

 return ret;
}

/* --- Unique context ID --------------------------------------------------- */

STATIC su_uid *su_uid_storage_fetch(pTHX_ UV depth) {
#define su_uid_storage_fetch(D) su_uid_storage_fetch(aTHX_ (D))
 su_uid **map, *uid;
 STRLEN alloc;
 dMY_CXT;

 map   = MY_CXT.uid_storage.map;
 alloc = MY_CXT.uid_storage.alloc;

 if (depth >= alloc) {
  STRLEN i;

  Renew(map, depth + 1, su_uid *);
  for (i = alloc; i <= depth; ++i)
   map[i] = NULL;

  MY_CXT.uid_storage.map   = map;
  MY_CXT.uid_storage.alloc = depth + 1;
 }

 uid = map[depth];

 if (!uid) {
  Newx(uid, 1, su_uid);
  uid->seq   = 0;
  uid->flags = 0;
  map[depth] = uid;
 }

 if (depth >= MY_CXT.uid_storage.used)
  MY_CXT.uid_storage.used = depth + 1;

 return uid;
}

STATIC int su_uid_storage_check(pTHX_ UV depth, UV seq) {
#define su_uid_storage_check(D, S) su_uid_storage_check(aTHX_ (D), (S))
 su_uid *uid;
 dMY_CXT;

 if (depth >= MY_CXT.uid_storage.used)
  return 0;

 uid = MY_CXT.uid_storage.map[depth];

 return uid && (uid->seq == seq) && (uid->flags & SU_UID_ACTIVE);
}

STATIC void su_uid_drop(pTHX_ void *ud_) {
 su_uid *uid = ud_;

 uid->flags &= ~SU_UID_ACTIVE;
}

STATIC void su_uid_bump(pTHX_ void *ud_) {
 su_ud_reap *ud  = ud_;

 SAVEDESTRUCTOR_X(su_uid_drop, ud->cb);
}

STATIC SV *su_uid_get(pTHX_ I32 cxix) {
#define su_uid_get(I) su_uid_get(aTHX_ (I))
 su_uid *uid;
 SV *uid_sv;
 UV depth;

 depth = su_uid_depth(cxix);
 uid   = su_uid_storage_fetch(depth);

 if (!(uid->flags & SU_UID_ACTIVE)) {
  su_ud_reap *ud;

  uid->seq = su_uid_seq_next(depth);
  uid->flags |= SU_UID_ACTIVE;

  Newx(ud, 1, su_ud_reap);
  SU_UD_ORIGIN(ud)  = NULL;
  SU_UD_HANDLER(ud) = su_uid_bump;
  ud->cb = (SV *) uid;
  su_init(ud, cxix, SU_SAVE_DESTRUCTOR_SIZE);
 }

 uid_sv = sv_newmortal();
 sv_setpvf(uid_sv, "%"UVuf"-%"UVuf, depth, uid->seq);
 return uid_sv;
}

#ifdef grok_number

#define su_grok_number(S, L, VP) grok_number((S), (L), (VP))

#else /* grok_number */

#define IS_NUMBER_IN_UV 0x1

STATIC int su_grok_number(pTHX_ const char *s, STRLEN len, UV *valuep) {
#define su_grok_number(S, L, VP) su_grok_number(aTHX_ (S), (L), (VP))
 STRLEN i;
 SV *tmpsv;

 /* This crude check should be good enough for a fallback implementation.
  * Better be too strict than too lax. */
 for (i = 0; i < len; ++i) {
  if (!isDIGIT(s[i]))
   return 0;
 }

 tmpsv = sv_newmortal();
 sv_setpvn(tmpsv, s, len);
 *valuep = sv_2uv(tmpsv);

 return IS_NUMBER_IN_UV;
}

#endif /* !grok_number */

STATIC int su_uid_validate(pTHX_ SV *uid) {
#define su_uid_validate(U) su_uid_validate(aTHX_ (U))
 const char *s;
 STRLEN len, p = 0;
 UV depth, seq;
 int type;

 s = SvPV_const(uid, len);

 while (p < len && s[p] != '-')
  ++p;
 if (p >= len)
  croak("UID contains only one part");

 type = su_grok_number(s, p, &depth);
 if (type != IS_NUMBER_IN_UV)
  croak("First UID part is not an unsigned integer");

 ++p; /* Skip '-'. As we used to have p < len, len - (p + 1) >= 0. */

 type = su_grok_number(s + p, len - p, &seq);
 if (type != IS_NUMBER_IN_UV)
  croak("Second UID part is not an unsigned integer");

 return su_uid_storage_check(depth, seq);
}

/* --- Context operations -------------------------------------------------- */

/* Remove sequences of BLOCKs having DB for stash, followed by a SUB context
 * for the debugger callback. */

STATIC I32 su_context_skip_db(pTHX_ I32 cxix) {
#define su_context_skip_db(C) su_context_skip_db(aTHX_ (C))
 I32 i;

 if (!PL_DBsub)
  return cxix;

 for (i = cxix; i > 0; --i) {
  PERL_CONTEXT *cx = cxstack + i;

  switch (CxTYPE(cx)) {
#if SU_HAS_PERL(5, 17, 1)
   case CXt_LOOP_PLAIN:
#endif
   case CXt_BLOCK:
    if (cx->blk_oldcop && CopSTASH(cx->blk_oldcop) == GvSTASH(PL_DBgv))
     continue;
    break;
   case CXt_SUB:
    if (cx->blk_sub.cv == GvCV(PL_DBsub)) {
     cxix = i - 1;
     continue;
    }
    break;
   default:
    break;
  }

  break;
 }

 return cxix;
}


STATIC I32 su_context_normalize_up(pTHX_ I32 cxix) {
#define su_context_normalize_up(C) su_context_normalize_up(aTHX_ (C))
 PERL_CONTEXT *cx;

 if (cxix <= 0)
  return 0;

 cx = cxstack + cxix;
 if (CxTYPE(cx) == CXt_BLOCK) {
  PERL_CONTEXT *prev = cx - 1;

  switch (CxTYPE(prev)) {
#if SU_HAS_PERL(5, 10, 0)
   case CXt_GIVEN:
   case CXt_WHEN:
#endif
#if SU_HAS_PERL(5, 11, 0)
   /* That's the only subcategory that can cause an extra BLOCK context */
   case CXt_LOOP_PLAIN:
#else
   case CXt_LOOP:
#endif
    if (cx->blk_oldcop == prev->blk_oldcop)
     return cxix - 1;
    break;
   case CXt_SUBST:
    if (cx->blk_oldcop && OP_SIBLING(cx->blk_oldcop)
                       && OP_SIBLING(cx->blk_oldcop)->op_type == OP_SUBST)
     return cxix - 1;
    break;
  }
 }

 return cxix;
}

STATIC I32 su_context_normalize_down(pTHX_ I32 cxix) {
#define su_context_normalize_down(C) su_context_normalize_down(aTHX_ (C))
 PERL_CONTEXT *next;

 if (cxix >= cxstack_ix)
  return cxstack_ix;

 next = cxstack + cxix + 1;
 if (CxTYPE(next) == CXt_BLOCK) {
  PERL_CONTEXT *cx = next - 1;

  switch (CxTYPE(cx)) {
#if SU_HAS_PERL(5, 10, 0)
   case CXt_GIVEN:
   case CXt_WHEN:
#endif
#if SU_HAS_PERL(5, 11, 0)
   /* That's the only subcategory that can cause an extra BLOCK context */
   case CXt_LOOP_PLAIN:
#else
   case CXt_LOOP:
#endif
    if (cx->blk_oldcop == next->blk_oldcop)
     return cxix + 1;
    break;
   case CXt_SUBST:
    if (next->blk_oldcop && OP_SIBLING(next->blk_oldcop)
                         && OP_SIBLING(next->blk_oldcop)->op_type == OP_SUBST)
     return cxix + 1;
    break;
  }
 }

 return cxix;
}

#define su_context_here() su_context_normalize_up(su_context_skip_db(cxstack_ix))

STATIC I32 su_context_gimme(pTHX_ I32 cxix) {
#define su_context_gimme(C) su_context_gimme(aTHX_ (C))
 I32 i;

 for (i = cxix; i >= 0; --i) {
  PERL_CONTEXT *cx = cxstack + i;

  switch (CxTYPE(cx)) {
   /* gimme is always G_ARRAY for loop contexts. */
#if SU_HAS_PERL(5, 11, 0)
   case CXt_LOOP_FOR:
   case CXt_LOOP_PLAIN:
   case CXt_LOOP_LAZYSV:
   case CXt_LOOP_LAZYIV:
#else
   case CXt_LOOP:
#endif
   case CXt_SUBST: {
    const COP *cop = cx->blk_oldcop;
    if (cop && OP_SIBLING(cop)) {
     switch (OP_SIBLING(cop)->op_flags & OPf_WANT) {
      case OPf_WANT_VOID:
       return G_VOID;
      case OPf_WANT_SCALAR:
       return G_SCALAR;
      case OPf_WANT_LIST:
       return G_ARRAY;
      default:
       break;
     }
    }
    break;
   }
   default:
    return CxGIMME(cx);
    break;
  }
 }

 return G_VOID;
}

/* --- Interpreter setup/teardown ------------------------------------------ */

STATIC void su_teardown(pTHX_ void *param) {
 su_uplevel_ud *cur;
 su_uid **map;
 dMY_CXT;

 map = MY_CXT.uid_storage.map;
 if (map) {
  STRLEN i;
  for (i = 0; i < MY_CXT.uid_storage.used; ++i)
   Safefree(map[i]);
  Safefree(map);
 }

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
 Zero(&(MY_CXT.unwind_storage.return_op), 1, LISTOP);
 MY_CXT.unwind_storage.return_op.op_type   = OP_RETURN;
 MY_CXT.unwind_storage.return_op.op_ppaddr = PL_ppaddr[OP_RETURN];

 Zero(&(MY_CXT.unwind_storage.proxy_op), 1, OP);
 MY_CXT.unwind_storage.proxy_op.op_type   = OP_STUB;
 MY_CXT.unwind_storage.proxy_op.op_ppaddr = NULL;

 Zero(&(MY_CXT.yield_storage.leave_op), 1, UNOP);
 MY_CXT.yield_storage.leave_op.op_type   = OP_STUB;
 MY_CXT.yield_storage.leave_op.op_ppaddr = NULL;

 Zero(&(MY_CXT.yield_storage.proxy_op), 1, OP);
 MY_CXT.yield_storage.proxy_op.op_type   = OP_STUB;
 MY_CXT.yield_storage.proxy_op.op_ppaddr = NULL;

 MY_CXT.uplevel_storage.top   = NULL;
 MY_CXT.uplevel_storage.root  = NULL;
 MY_CXT.uplevel_storage.count = 0;

 MY_CXT.uid_storage.map   = NULL;
 MY_CXT.uid_storage.used  = 0;
 MY_CXT.uid_storage.alloc = 0;

 call_atexit(su_teardown, NULL);

 return;
}

/* --- XS ------------------------------------------------------------------ */

#define SU_GET_CONTEXT(A, B, D) \
 STMT_START {                   \
  if (items > A) {              \
   SV *csv = ST(B);             \
   if (!SvOK(csv))              \
    goto default_cx;            \
   cxix = SvIV(csv);            \
   if (cxix < 0)                \
    cxix = 0;                   \
   else if (cxix > cxstack_ix)  \
    goto default_cx;            \
  } else {                      \
default_cx:                     \
   cxix = (D);                  \
  }                             \
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

#if SU_HAS_PERL(5, 10, 0)
# define SU_INFO_COUNT 11
#else
# define SU_INFO_COUNT 10
#endif

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

 SU_GET_CONTEXT(0, items - 1, cxstack_ix);
 do {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
   case CXt_EVAL:
   case CXt_FORMAT:
    MY_CXT.unwind_storage.cxix   = cxix;
    MY_CXT.unwind_storage.items  = items;
    MY_CXT.unwind_storage.savesp = PL_stack_sp;
    if (items > 0) {
     MY_CXT.unwind_storage.items--;
     MY_CXT.unwind_storage.savesp--;
    }
    /* pp_entersub will want to sanitize the stack after returning from there
     * Screw that, we're insane!
     * dXSARGS calls POPMARK, so we need to match PL_markstack_ptr[1] */
    if (GIMME_V == G_SCALAR)
     PL_stack_sp = PL_stack_base + PL_markstack_ptr[1] + 1;
    SAVEDESTRUCTOR_X(su_unwind, NULL);
    return;
   default:
    break;
  }
 } while (--cxix >= 0);
 croak("Can't return outside a subroutine");
}

STATIC const char su_yield_name[] = "yield";

XS(XS_Scope__Upper_yield); /* prototype to pass -Wmissing-prototypes */

XS(XS_Scope__Upper_yield) {
#ifdef dVAR
 dVAR; dXSARGS;
#else
 dXSARGS;
#endif
 dMY_CXT;
 I32 cxix;

 PERL_UNUSED_VAR(cv); /* -W */
 PERL_UNUSED_VAR(ax); /* -Wall */

 SU_GET_CONTEXT(0, items - 1, su_context_here());
 MY_CXT.yield_storage.cxix   = cxix;
 MY_CXT.yield_storage.items  = items;
 MY_CXT.yield_storage.savesp = PL_stack_sp;
 if (items > 0) {
  MY_CXT.yield_storage.items--;
  MY_CXT.yield_storage.savesp--;
 }
 /* See XS_Scope__Upper_unwind */
 if (GIMME_V == G_SCALAR)
  PL_stack_sp = PL_stack_base + PL_markstack_ptr[1] + 1;
 SAVEDESTRUCTOR_X(su_yield, su_yield_name);
 return;
}

STATIC const char su_leave_name[] = "leave";

XS(XS_Scope__Upper_leave); /* prototype to pass -Wmissing-prototypes */

XS(XS_Scope__Upper_leave) {
#ifdef dVAR
 dVAR; dXSARGS;
#else
 dXSARGS;
#endif
 dMY_CXT;
 I32 cxix;

 PERL_UNUSED_VAR(cv); /* -W */
 PERL_UNUSED_VAR(ax); /* -Wall */

 MY_CXT.yield_storage.cxix   = su_context_here();
 MY_CXT.yield_storage.items  = items;
 MY_CXT.yield_storage.savesp = PL_stack_sp;
 /* See XS_Scope__Upper_unwind */
 if (GIMME_V == G_SCALAR)
  PL_stack_sp = PL_stack_base + PL_markstack_ptr[1] + 1;
 SAVEDESTRUCTOR_X(su_yield, su_leave_name);
 return;
}

MODULE = Scope::Upper            PACKAGE = Scope::Upper

PROTOTYPES: ENABLE

BOOT:
{
 HV *stash;

 MUTEX_INIT(&su_uid_seq_counter_mutex);

 su_uid_seq_counter.seqs = NULL;
 su_uid_seq_counter.size = 0;

 stash = gv_stashpv(__PACKAGE__, 1);
 newCONSTSUB(stash, "TOP",           newSViv(0));
 newCONSTSUB(stash, "SU_THREADSAFE", newSVuv(SU_THREADSAFE));

 newXSproto("Scope::Upper::unwind", XS_Scope__Upper_unwind, file, NULL);
 newXSproto("Scope::Upper::yield",  XS_Scope__Upper_yield,  file, NULL);
 newXSproto("Scope::Upper::leave",  XS_Scope__Upper_leave,  file, NULL);

 su_setup();
}

#if SU_THREADSAFE

void
CLONE(...)
PROTOTYPE: DISABLE
PREINIT:
 su_uid_storage new_cxt;
PPCODE:
 {
  dMY_CXT;
  new_cxt.map   = NULL;
  new_cxt.used  = 0;
  new_cxt.alloc = 0;
  su_uid_storage_dup(&new_cxt, &MY_CXT.uid_storage, MY_CXT.uid_storage.used);
 }
 {
  MY_CXT_CLONE;
  MY_CXT.uplevel_storage.top   = NULL;
  MY_CXT.uplevel_storage.root  = NULL;
  MY_CXT.uplevel_storage.count = 0;
  MY_CXT.uid_storage           = new_cxt;
 }
 XSRETURN(0);

#endif /* SU_THREADSAFE */

void
HERE()
PROTOTYPE:
PREINIT:
 I32 cxix;
PPCODE:
 cxix = su_context_here();
 EXTEND(SP, 1);
 mPUSHi(cxix);
 XSRETURN(1);

void
UP(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0, su_context_here());
 if (cxix > 0) {
  --cxix;
  cxix = su_context_skip_db(cxix);
  cxix = su_context_normalize_up(cxix);
 }
 EXTEND(SP, 1);
 mPUSHi(cxix);
 XSRETURN(1);

void
SUB(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0, cxstack_ix);
 EXTEND(SP, 1);
 for (; cxix >= 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   default:
    continue;
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
    mPUSHi(cxix);
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
 SU_GET_CONTEXT(0, 0, cxstack_ix);
 EXTEND(SP, 1);
 for (; cxix >= 0; --cxix) {
  PERL_CONTEXT *cx = cxstack + cxix;
  switch (CxTYPE(cx)) {
   default:
    continue;
   case CXt_EVAL:
    mPUSHi(cxix);
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
 cxix = su_context_here();
 while (--level >= 0) {
  if (cxix <= 0)
   break;
  --cxix;
  cxix = su_context_skip_db(cxix);
  cxix = su_context_normalize_up(cxix);
 }
 EXTEND(SP, 1);
 mPUSHi(cxix);
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
 EXTEND(SP, 1);
 mPUSHi(cxix);
 XSRETURN(1);

void
want_at(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
PPCODE:
 SU_GET_CONTEXT(0, 0, cxstack_ix);
 EXTEND(SP, 1);
 while (cxix > 0) {
  PERL_CONTEXT *cx = cxstack + cxix--;
  switch (CxTYPE(cx)) {
   case CXt_SUB:
    if (PL_DBsub && cx->blk_sub.cv == GvCV(PL_DBsub))
     continue;
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
context_info(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
 const PERL_CONTEXT *cx, *dbcx;
 COP *cop;
PPCODE:
 SU_GET_CONTEXT(0, 0, su_context_skip_db(cxstack_ix));
 cxix = su_context_normalize_up(cxix);
 cx   = cxstack + cxix;
 dbcx = cx;
 if (PL_DBsub && cxix && (CxTYPE(cx) == CXt_SUB || CxTYPE(cx) == CXt_FORMAT)) {
  I32 i = su_context_skip_db(cxix - 1) + 1;
  if (i < cxix && CxTYPE(cxstack + i) == CXt_SUB)
   cx = cxstack + i;
 }
 cop  = cx->blk_oldcop;
 EXTEND(SP, SU_INFO_COUNT);
 /* stash (0) */
 {
  HV *stash = CopSTASH(cop);
  if (stash)
   PUSHs(su_newmortal_pvn(HvNAME(stash), HvNAMELEN(stash)));
  else
   PUSHs(&PL_sv_undef);
 }
 /* file (1) */
 PUSHs(su_newmortal_pvn(OutCopFILE(cop), OutCopFILE_len(cop)));
 /* line (2) */
 mPUSHi(CopLINE(cop));
 /* subroutine (3) and has_args (4) */
 switch (CxTYPE(cx)) {
  case CXt_SUB:
  case CXt_FORMAT: {
   GV *cvgv = CvGV(dbcx->blk_sub.cv);
   if (cvgv && isGV(cvgv)) {
    SV *sv = sv_newmortal();
    gv_efullname3(sv, cvgv, NULL);
    PUSHs(sv);
   } else {
    PUSHs(su_newmortal_pvs("(unknown)"));
   }
   if (CxHASARGS(cx))
    PUSHs(&PL_sv_yes);
   else
    PUSHs(&PL_sv_no);
   break;
  }
  case CXt_EVAL:
   PUSHs(su_newmortal_pvs("(eval)"));
   mPUSHi(0);
   break;
  default:
   PUSHs(&PL_sv_undef);
   PUSHs(&PL_sv_undef);
 }
 /* gimme (5) */
 switch (su_context_gimme(cxix)) {
  case G_ARRAY:
   PUSHs(&PL_sv_yes);
   break;
  case G_SCALAR:
   PUSHs(&PL_sv_no);
   break;
  default: /* G_VOID */
   PUSHs(&PL_sv_undef);
   break;
 }
 /* eval text (6) and is_require (7) */
 switch (CxTYPE(cx)) {
  case CXt_EVAL:
   if (CxOLD_OP_TYPE(cx) == OP_ENTEREVAL) {
    /* eval STRING */
#if SU_HAS_PERL(5, 17, 4)
    PUSHs(newSVpvn_flags(SvPVX(cx->blk_eval.cur_text),
                         SvCUR(cx->blk_eval.cur_text)-2,
                         SvUTF8(cx->blk_eval.cur_text)|SVs_TEMP));
#else
    PUSHs(cx->blk_eval.cur_text);
#endif
    PUSHs(&PL_sv_no);
    break;
   } else if (cx->blk_eval.old_namesv) {
    /* require */
    PUSHs(sv_mortalcopy(cx->blk_eval.old_namesv));
    PUSHs(&PL_sv_yes);
    break;
   }
   /* FALLTHROUGH */
  default:
   /* Anything else including eval BLOCK */
   PUSHs(&PL_sv_undef);
   PUSHs(&PL_sv_undef);
   break;
 }
 /* hints (8) */
 mPUSHi(CopHINTS_get(cop));
 /* warnings (9) */
 {
  SV *mask = NULL;
#if SU_HAS_PERL(5, 9, 4)
  STRLEN *old_warnings = cop->cop_warnings;
#else
  SV *old_warnings = cop->cop_warnings;
#endif
  if (old_warnings == pWARN_STD) {
   if (PL_dowarn & G_WARN_ON)
    goto context_info_warnings_on;
   else
#if SU_HAS_PERL(5, 17, 4)
    mask = &PL_sv_undef;
#else
    goto context_info_warnings_off;
#endif
  } else if (old_warnings == pWARN_NONE) {
context_info_warnings_off:
   mask = su_newmortal_pvn(WARN_NONEstring, WARNsize);
  } else if (old_warnings == pWARN_ALL) {
   HV *bits;
context_info_warnings_on:
#if SU_HAS_PERL(5, 8, 7)
   bits = get_hv("warnings::Bits", 0);
   if (bits) {
    SV **bits_all = hv_fetchs(bits, "all", FALSE);
    if (bits_all)
     mask = sv_mortalcopy(*bits_all);
   }
#endif
   if (!mask)
    mask = su_newmortal_pvn(WARN_ALLstring, WARNsize);
  } else {
#if SU_HAS_PERL(5, 9, 4)
   mask = su_newmortal_pvn((char *) (old_warnings + 1), old_warnings[0]);
#else
   mask = sv_mortalcopy(old_warnings);
#endif
  }
  PUSHs(mask);
 }
#if SU_HAS_PERL(5, 10, 0)
 /* hints hash (10) */
 {
  COPHH *hints_hash = CopHINTHASH_get(cop);
  if (hints_hash) {
   SV *rhv = sv_2mortal(newRV_noinc((SV *) cophh_2hv(hints_hash, 0)));
   PUSHs(rhv);
  } else {
   PUSHs(&PL_sv_undef);
  }
 }
#endif
 XSRETURN(SU_INFO_COUNT);

void
reap(SV *hook, ...)
PROTOTYPE: &;$
PREINIT:
 I32 cxix;
 su_ud_reap *ud;
CODE:
 SU_GET_CONTEXT(1, 1, su_context_skip_db(cxstack_ix));
 cxix = su_context_normalize_down(cxix);
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
 SU_GET_CONTEXT(2, 2, su_context_skip_db(cxstack_ix));
 cxix = su_context_normalize_down(cxix);
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
 SU_GET_CONTEXT(3, 3, su_context_skip_db(cxstack_ix));
 cxix = su_context_normalize_down(cxix);
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
 SU_GET_CONTEXT(2, 2, su_context_skip_db(cxstack_ix));
 cxix = su_context_normalize_down(cxix);
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
 SU_GET_CONTEXT(1, items - 1, cxstack_ix);
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
    /* su_uplevel() takes care of extending the stack if needed. */
    ret = su_uplevel((CV *) code, cxix, args);
    XSRETURN(ret);
   default:
    break;
  }
 } while (--cxix >= 0);
 croak("Can't uplevel outside a subroutine");

void
uid(...)
PROTOTYPE: ;$
PREINIT:
 I32 cxix;
 SV *uid;
PPCODE:
 SU_GET_CONTEXT(0, 0, su_context_here());
 uid = su_uid_get(cxix);
 EXTEND(SP, 1);
 PUSHs(uid);
 XSRETURN(1);

void
validate_uid(SV *uid)
PROTOTYPE: $
PREINIT:
 SV *ret;
PPCODE:
 ret = su_uid_validate(uid) ? &PL_sv_yes : &PL_sv_no;
 EXTEND(SP, 1);
 PUSHs(ret);
 XSRETURN(1);
