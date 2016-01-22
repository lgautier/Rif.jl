/* Copyright - 2012 - Laurent Gautier */
#include <stdlib.h>
#include <stdbool.h>
#include <strings.h>
#include <R.h>
#include <Rinternals.h>
#include <Rinterface.h>
#include <Rversion.h>
#include <Rembedded.h>
#include <Rdefines.h>
#include <R_ext/eventloop.h>
#include <R_ext/Parse.h>
// #ifdef HAS_READLINE
// #include <readline/readline.h>
// #endif

#include "r_utils.h"

/* char *initargv[]= {"JuliaEmbeddedR", "--verbose"}; */
typedef struct {
  int argc;
  char **argv;
} InitArgv;


/* struct { */
/*   list of arguments along their names */
/* } call; */

static InitArgv *initargv = NULL;

static SEXP errMessage_SEXP;

/* R does not accept any concurrency. We store the
   status of the R engine in global and this must
   be checked before anything R-related is performed. */
#define RINTERF_INITIALIZED (0x1)
#define RINTERF_IDLE (0x2)
/* Init args set */
#define RINTERF_ARGSSET (0x4)

#define RINTERF_READY (RINTERF_ARGSSET & RINTERF_INITIALIZED & RINTERF_IDLE)

static int RStatus = RINTERF_IDLE;

#define RINTERF_ISINITIALIZED() (RStatus & RINTERF_INITIALIZED)
#define RINTERF_ISBUSY() (!(RStatus & RINTERF_IDLE))
#define RINTERF_HASARGSSET() (RStatus & RINTERF_ARGSSET)

#define RINTERF_ISREADY() ((RStatus & RINTERF_IDLE) && (RStatus & RINTERF_ARGSSET) && (RStatus & RINTERF_INITIALIZED))

int
EmbeddedR_Rstatus(void) {
  return RStatus;
}

/* Is the embeded R initialized ?
   Return 0 or 1*/
int
EmbeddedR_isInitialized (void) {
  return RINTERF_ISINITIALIZED() == 0 ? 0 : 1;
}

/* Is the R interface busy (no concurrent access possible with R) ?
Return 0 or 1*/
int
EmbeddedR_isBusy (void) {
  return RINTERF_ISBUSY() == 0 ? 0 : 1;
}

/* Are the paramaters for initializing an embedded R set ?
   Return 0 or 1*/
int
EmbeddedR_hasArgsSet (void) {
  return RINTERF_HASARGSSET() == 0 ? 0 : 1;
}

/* Is the R interface ready (embedded R initialized and idle) ?
   Return 0 or 1*/
int
EmbeddedR_isReady (void) {
  return RINTERF_ISREADY() == 0 ? 0 : 1;
}


/* Set initialization arguments to start R.
 We could also allow initR() below to accept arguments
 as parameters but this would be problematic if importing
 a library has the initialization / start of R as a side effect.
 It would not allow to change the initialization parameters as
 cleanly / explicitly.
 Return 0 on success, -1 on error.
*/
int
EmbeddedR_setInitArgs (const int argc, const char **argv) {
  if (RINTERF_ISBUSY()) {
    /* It is not possible to set initialisation arguments after R was started */
    printf("R is already running.\n");
    return -1;
  } else {
    RStatus ^= RINTERF_IDLE;
  }
  if ( initargv == NULL ) {
    initargv = (InitArgv*)(calloc(1, sizeof(InitArgv)));
    initargv->argc = 0;
    if (initargv == NULL) {
      printf("Could not allocate memory for the initialisation parameters.\n");
      RStatus ^= RINTERF_IDLE;
      return -1;
    }
  }
  int arg_i;
  if ( initargv->argc > 0 ) {
    /* FIXME: Using free (and calloc below) - may be consider to make
     this slightly configurable for other bridges ? */
    for (arg_i = 0; arg_i < argc; arg_i++) {
      free(initargv->argv[arg_i]);
    }
    free(initargv->argv);
    initargv->argc = 0;
  }
  initargv->argc = argc;
  initargv->argv = (char**)calloc(argc, sizeof(char*));
  for (arg_i = 0; arg_i < argc; arg_i++) {
    initargv->argv[arg_i] = (char*)(calloc(strlen(argv[arg_i]), sizeof(char*)));
    strcpy(initargv->argv[arg_i], argv[arg_i]);
  }
  RStatus |= RINTERF_ARGSSET;
  RStatus ^= RINTERF_IDLE;
  return 0;
}

/*FIXME: return an array of strings */
void
EmbeddedR_getInitArgs (void) {
  RStatus ^= RINTERF_IDLE;
  if (! RINTERF_HASARGSSET() ) {
    printf("Initialization parameters not yet set.\n");
    RStatus ^= RINTERF_IDLE;
    return;
  }
  if (initargv == NULL) {
    printf("Ouch. Parameters missing. Why am I here ?!.\n");
    RStatus ^= RINTERF_IDLE;
    return;
  }
  printf("%i arguments:\n", initargv->argc);
  int arg_i;
  for (arg_i=0; arg_i < initargv->argc; arg_i++) {
    printf("  %i: %s\n", arg_i, initargv->argv[arg_i]);
  }
  RStatus ^= RINTERF_IDLE;
}

/* Initialize R, that is start an embedded R.
   Parameters are found in the global 'initargv'.

   Return 0 on success, -1 on failure.
 */
int
EmbeddedR_init(void) {
  if (RINTERF_ISREADY()) {
    printf("R is already ready.\n");
    return -1;
  }
  RStatus ^= RINTERF_IDLE;
  if (! RINTERF_HASARGSSET()) {
    /* Initialization arguments must be set and
       R can only be initialized once */
    printf("Initialization parameters must be set first.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  }

  if (! initargv) {
    printf("No initialisation argument. This should have been caught earlier.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  }
  int status = Rf_initEmbeddedR(initargv->argc, initargv->argv);
  if (status < 0) {
    printf("R initialization failed.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  }

  /* R_Interactive = TRUE; */
  /* #ifdef RIF_HAS_RSIGHAND */
  /* R_SignalHandlers = 0; */
  /* #endif */

  /* #ifdef CSTACK_DEFNS */
  /* /\* Taken from JRI: */
  /*  * disable stack checking, because threads will thow it off *\/ */
  /* R_CStackStart = (uintptr_t) -1; */
  /* R_CStackLimit = (uintptr_t) -1; */
  /* /\* --- *\/ */
  /* #endif */

  //setup_Rmainloop();

  /*FIXME: setting readline variables so R's oddly static declarations
    become harmless*/
// #ifdef HAS_READLINE
//   char *rl_completer, *rl_basic;
//   rl_completer = strndup(rl_completer_word_break_characters, 200);
//   rl_completer_word_break_characters = rl_completer;

//   rl_basic = strndup(rl_basic_word_break_characters, 200);
//   rl_basic_word_break_characters = rl_basic;
// #endif
  /* */
  errMessage_SEXP = findVar(Rf_install("geterrmessage"),
                            R_BaseNamespace);

  RStatus |= (RINTERF_INITIALIZED);
  RStatus ^= RINTERF_IDLE;
  return 0;
}

/* Parse a string as R code.
   Return NULL on error */
SEXP
EmbeddedR_parse(char *string) {
  if (! RINTERF_ISREADY()) {
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  ParseStatus status;
  SEXP cmdSexp, cmdExpr;
  PROTECT(cmdSexp = allocVector(STRSXP, 1));
  SET_STRING_ELT(cmdSexp, 0, mkChar(string));
  PROTECT(cmdExpr = R_ParseVector(cmdSexp, -1, &status, R_NilValue));
  if (status != PARSE_OK) {
    UNPROTECT(2);
    RStatus ^= RINTERF_IDLE;
    return NULL;
  }
  R_PreserveObject(cmdExpr);
  UNPROTECT(2);
  RStatus ^= RINTERF_IDLE;
  return cmdExpr;
}

/* Evaluate an expression (EXPRSXP, such as one that would
   be returned by Embedded_parse()) in an environment.
   Return NULL on error */
SEXP
EmbeddedR_eval(SEXP expression, SEXP envir) {
  if (! RINTERF_ISREADY()) {
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP res = R_NilValue;
  int errorOccurred = 0;
  int i;
  for(i = 0; i < LENGTH(expression); i++) {
    res = R_tryEval(VECTOR_ELT(expression,i), envir, &errorOccurred);
  }
  if (errorOccurred) {
    res = NULL;
  }
  RStatus ^= RINTERF_IDLE;
  return res;
}

/* Return -1 on failure */
int
Sexp_named(const SEXP sexp) {
  if (! RINTERF_ISREADY()) {
    return -1;
  }
  int res = NAMED(sexp);
  return res;
}

/* Return -1 on failure */
int
Sexp_typeof(const SEXP sexp) {
  if (! RINTERF_ISREADY()) {
    return -1;
  }
  int res = TYPEOF(sexp);
  return res;
}

/* Return -1 on failure */
int
Sexp_length(const SEXP sexp) {
  if (! RINTERF_ISREADY()) {
    return -1;
  }
  int res = LENGTH(sexp);
  return res;
}

/* Return NULL on failure */
SEXP
Sexp_get_names(const SEXP sexp) {
  if (! RINTERF_ISREADY()) {
    return NULL;
  }
  SEXP res = GET_NAMES(sexp);
  R_PreserveObject(res);
  return res;
}

void
Sexp_set_names(SEXP sexp,
	   const SEXP sexp_names) {
  if (! RINTERF_ISREADY()) {
    return;
  }
  SET_NAMES(sexp, sexp_names);
}

/* Return -1 on failure */
int
Sexp_ndims(const SEXP sexp) {
  if (! RINTERF_ISREADY()) {
    return -1;
  }
  SEXP dims = getAttrib(sexp, R_DimSymbol);
  int res;
  if (Rf_isNull(dims))
    res = 1;
  else
    res = LENGTH(dims);
  return res;
}

/* Return NULL on failure */
SEXP
Sexp_getAttribute(const SEXP sexp,
		  char *name) {
  if (! RINTERF_ISREADY()) {
    return NULL;
  }
  SEXP res = Rf_getAttrib(sexp, Rf_install(name));
  if (Rf_isNull(res)) {
    res = NULL;
  } else {
    R_PreserveObject(res);
  }
  return res;
}

void
Sexp_setAttribute(SEXP sexp,
		  char *name,
		  const SEXP sexp_attr) {
  if (! RINTERF_ISREADY()) {
    return;
  }
  Rf_setAttrib(sexp, Rf_install(name), sexp_attr);
}

/* Return NULL on failure */
SEXP
Sexp_evalPromise(const SEXP sexp) {
  if (TYPEOF(sexp) != PROMSXP) {
    printf("Not a promise.\n");
    return NULL;
  }
  SEXP env, sexp_concrete;
  PROTECT(env = PRENV(sexp));
  if (env == R_NilValue) {
    UNPROTECT(1);
    PROTECT(env = R_BaseEnv);
  }
  PROTECT(sexp_concrete = eval(sexp, env));
  R_PreserveObject(sexp_concrete);
  UNPROTECT(2);
  return sexp_concrete;
}

void
EmbeddedR_ProcessEvents()
{
  if (! RINTERF_HASARGSSET()) {
    printf("R should not process events before being initialized.");
    return;
  }
  if (RINTERF_ISBUSY()) {
    printf("Concurrent access to R is not allowed.");
    return;
  }
  // setlock
  RStatus = RStatus | RINTERF_ISBUSY();
#if defined(HAVE_AQUA) || (defined(Win32) || defined(Win64))
  /* Can the call to R_ProcessEvents somehow fail ? */
  R_ProcessEvents();
#endif
#if ! (defined(Win32) || defined(Win64))
  R_runHandlers(R_InputHandlers, R_checkActivity(0, 1));
#endif
  // freelock
  RStatus = RStatus ^ RINTERF_ISBUSY();
}

#define STRINGIFY(x) #x

/* Return 0 on failure (not quite reliable) */
#define RINTERF_GETITEM(rpointer, sexptype, ctype)			\
  if (TYPEOF(sexp) != sexptype) {					\
    printf("Not an R vector of type %s.\n", STRINGIFY(sexptype));	\
    /*FIXME: return int or NULL ?*/					\
    return 0;								\
  }									\
  if ((i < 0) || (i >= LENGTH(sexp))) {					\
    printf("Out-of-bound. (looking for element %i while length is %i)\n", i, LENGTH(sexp)); \
    /*FIXME: return int or NULL ?*/					\
    return 0;								\
  }									\
  ctype res = rpointer(sexp)[i];					\
			    return res;					\

#define RINTERF_IFROMIJ(sexp, i, j)		\
  int nr = Rf_nrows(sexp);			\
  i  = j * nr + i;				\



/* return the index for the first named element matching `name` */
/* Return NA if not found*/
R_len_t
nameIndex(const SEXP sexp, const char *name) {
  SEXP sexp_item, sexp_names;
  char *name_item;
  PROTECT(sexp_names = getAttrib(sexp, R_NamesSymbol));
  R_len_t n = LENGTH(sexp);
  R_len_t i;
  cetype_t encoding;
  int found = 0;
  for (i = 0; i < n; i++) {
    sexp_item = STRING_ELT(sexp_names, i);
    encoding = Rf_getCharCE(sexp_item);
    switch (encoding) {
    case CE_UTF8:
      name_item = (char *)translateCharUTF8(sexp_item);
      break;
    default:
      name_item = (char *)CHAR(sexp_item);
      break;
    }
    if (strcmp(name, name_item)) {
      found = 1;
      break;
    }
  }
  if (found) {
    return i;
  } else {
    return R_NaInt;
  }
}

/* Return 0 on failure (should be NaN) */
#define RINTERF_GETBYNAME(rpointer, sexptype, ctype, name)		\
  if (TYPEOF(sexp) != sexptype) {					\
    printf("Not an R vector of type %s.\n", STRINGIFY(sexptype));	\
    /*FIXME: return int or NULL ?*/					\
    return 0;								\
  }									\
  R_len_t i = nameIndex(sexp, name);					\
  ctype res = 0;								\
  if (i != R_NaInt) {							\
    res = rpointer(sexp)[i];						\
  } else {								\
    printf("*** Name `%s` not found.\n", name);				\
  }									\
  return res;								\



/* Return NULL on failure */
char* SexpStrVector_getitem(const SEXP sexp, int i) {
  if (TYPEOF(sexp) != STRSXP) {
    printf("Not an R vector of type STRSXP.\n");
    return NULL;
  }
  if ((i < 0) || (i >= LENGTH(sexp))) {
    printf("Out-of-bound.\n");
    /*FIXME: return int or NULL ?*/
    return NULL;
  }
  char *res;
  SEXP sexp_item;
  PROTECT(sexp_item = STRING_ELT(sexp, (R_len_t)i));
  cetype_t encoding = Rf_getCharCE(sexp_item);
  switch (encoding) {
  case CE_UTF8:
    res = (char *)translateCharUTF8(sexp_item);
    break;
  default:
    res = (char *)CHAR(sexp_item);
    break;
  }
  UNPROTECT(1);
  return res;
}

/* Return -1 on failure */
char* SexpStrVectorMatrix_getitem(const SEXP sexp, int i, int j) {
  RINTERF_IFROMIJ(sexp, i, j);
  return SexpStrVector_getitem(sexp, i);
}

/* Return -1 on failure */
int SexpStrVector_setitem(const SEXP sexp, int i, char *item) {
  if (TYPEOF(sexp) != STRSXP) {
    printf("Not an R vector of type STRSXP.\n");
    return -1;
  }
  if ((i < 0) || (i >= LENGTH(sexp))) {
    printf("Out-of-bound.\n");
    /*FIXME: return int or NULL ?*/
    return -1;
  }
  SEXP newstring = mkChar(item);
  SET_STRING_ELT(sexp, (R_len_t)i, newstring);
  return 0;
}

int SexpStrVectorMatrix_setitem(const SEXP sexp, int i, int j, char *item) {
  RINTERF_IFROMIJ(sexp, i, j);
  return SexpStrVector_setitem(sexp, i, item);
}

double SexpDoubleVector_getitem(const SEXP sexp, int i) {
  RINTERF_GETITEM(NUMERIC_POINTER, REALSXP, double)
}
double SexpDoubleVector_getbyname(const SEXP sexp, char *name) {
  RINTERF_GETBYNAME(NUMERIC_POINTER, REALSXP, double, name)
}

double SexpDoubleVectorMatrix_getitem(const SEXP sexp, int i, int j) {
  RINTERF_IFROMIJ(sexp, i, j)
    RINTERF_GETITEM(NUMERIC_POINTER, REALSXP, double)
    }


int SexpIntVector_getitem(const SEXP sexp, int i) {
  RINTERF_GETITEM(INTEGER_POINTER, INTSXP, int)
    }
int SexpIntVector_getbyname(const SEXP sexp, char *name) {
  RINTERF_GETBYNAME(INTEGER_POINTER, INTSXP, int, name)
    }
int SexpIntVectorMatrix_getitem(const SEXP sexp, int i, int j) {
  RINTERF_IFROMIJ(sexp, i, j)
    RINTERF_GETITEM(INTEGER_POINTER, INTSXP, int)
    }

int SexpBoolVector_getitem(const SEXP sexp, int i) {
  RINTERF_GETITEM(LOGICAL_POINTER, LGLSXP, int)
    }
int SexpBoolVector_getbyname(const SEXP sexp, char *name) {
  RINTERF_GETBYNAME(LOGICAL_POINTER, LGLSXP, int, name)
    }

int SexpBoolVectorMatrix_getitem(const SEXP sexp, int i, int j) {
  RINTERF_IFROMIJ(sexp, i, j)
    RINTERF_GETITEM(LOGICAL_POINTER, LGLSXP, int)
    }

#define RINTERF_SETNUMITEM(rpointer, sexptype)				\
  if (TYPEOF(sexp) != sexptype) {					\
    printf("Not an R vector of type %s.\n", STRINGIFY(sexptype));	\
    /*FIXME: return int or NULL ?*/					\
    return -1;								\
  }									\
  if (i >= LENGTH(sexp)) {						\
    printf("Out-of-bound.\n");						\
    /*FIXME: return int or NULL ?*/					\
    return -1;								\
  }									\
  rpointer(sexp)[i] = value;						\
  return 0;								\

#define RINTERF_SETBYNAME(rpointer, sexptype, name)			\
  if (TYPEOF(sexp) != sexptype) {					\
    printf("Not an R vector of type %s.\n", STRINGIFY(sexptype));	\
    /*FIXME: return int or NULL ?*/					\
    return -1;								\
  }									\
  R_len_t i = nameIndex(sexp, name);					\
  if (i != R_NaInt) {							\
    rpointer(sexp)[i] = value;						\
    return 0;								\
  } else {								\
    return -1;								\
  }									\


int SexpDoubleVector_setitem(const SEXP sexp, int i, double value) {
  RINTERF_SETNUMITEM(NUMERIC_POINTER, REALSXP)
}
int SexpDoubleVector_setbyname(const SEXP sexp, char *name, double value) {
  RINTERF_SETBYNAME(NUMERIC_POINTER, REALSXP, name)
}

int SexpDoubleVectorMatrix_setitem(const SEXP sexp, int i, int j,
				   double value) {
  RINTERF_IFROMIJ(sexp, i, j)
  RINTERF_SETNUMITEM(NUMERIC_POINTER, REALSXP)
}


int SexpIntVector_setitem(const SEXP sexp, int i, int value) {
  RINTERF_SETNUMITEM(INTEGER_POINTER, INTSXP)
}
int SexpIntVector_setbyname(const SEXP sexp, char *name, int value) {
  RINTERF_SETBYNAME(INTEGER_POINTER, INTSXP, name)
}
int SexpIntVectorMatrix_setitem(const SEXP sexp, int i, int j, int value) {
  RINTERF_IFROMIJ(sexp, i, j)
  RINTERF_SETNUMITEM(INTEGER_POINTER, INTSXP)
}

int SexpBoolVector_setitem(const SEXP sexp, int i, int value) {
  RINTERF_SETNUMITEM(LOGICAL_POINTER, LGLSXP)
}
int SexpBoolVector_setbyname(const SEXP sexp, char *name, int value) {
  RINTERF_SETBYNAME(LOGICAL_POINTER, LGLSXP, name)
}
int SexpBoolVectorMatrix_setitem(const SEXP sexp, int i, int j, int value) {
  RINTERF_IFROMIJ(sexp, i, j)
  RINTERF_SETNUMITEM(LOGICAL_POINTER, LGLSXP)
}

#define RINTERF_NEWVECTOR_NOFILL(rconstructor_call)			\
  if (! RINTERF_ISREADY()) {						\
    printf("R is not ready.\n");					\
    return NULL;							\
    }									\
  RStatus ^= RINTERF_IDLE;						\
  SEXP sexp = rconstructor_call;					\
  R_PreserveObject(sexp);						\
  RStatus ^= RINTERF_IDLE;						\
  return sexp;								\


#define RINTERF_NEWVECTOR(rpointer, rconstructor_call, ctype)		\
  if (! RINTERF_ISREADY()) {						\
    printf("R is not ready.\n");					\
    return NULL;							\
    }									\
  RStatus ^= RINTERF_IDLE;						\
  SEXP sexp = rconstructor_call;					\
  if (sexp == NULL) {							\
    printf("Problem while creating R vector.\n");			\
    RStatus ^= RINTERF_IDLE;						\
    return sexp;							\
  }									\
  PROTECT(sexp);							\
  ctype *sexp_p = rpointer(sexp);					\
  int i;								\
  for (i = 0; i < n; i++) {						\
    sexp_p[i] = v[i];							\
  }									\
  R_PreserveObject(sexp);						\
  UNPROTECT(1);								\
  RStatus ^= RINTERF_IDLE;						\
  return sexp;								\


SEXP
SexpDoubleVector_new(double *v, int n) {
  RINTERF_NEWVECTOR(NUMERIC_POINTER, NEW_NUMERIC(n), double)
}

SEXP
SexpDoubleVector_new_nofill(int n) {
  RINTERF_NEWVECTOR_NOFILL(NEW_NUMERIC(n))
}

SEXP
SexpDoubleVectorMatrix_new(double *v, int nx, int ny) {
  int n = nx * ny;
  RINTERF_NEWVECTOR(NUMERIC_POINTER, allocMatrix(REALSXP, nx, ny), double)
}

SEXP
SexpDoubleVectorMatrix_new_nofill(int nx, int ny) {
  RINTERF_NEWVECTOR_NOFILL(allocMatrix(REALSXP, nx, ny))
}

SEXP
SexpStrVector_new(char **v, int n) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp = NEW_CHARACTER(n);
  if (sexp == NULL) {
    printf("Problem while creating R vector.\n");
    RStatus ^= RINTERF_IDLE;
    return sexp;
  }
  PROTECT(sexp);
  SEXP str_R;
  int i;
  for (i = 0; i < n; i++) {
    str_R = mkChar(v[i]);
    SET_STRING_ELT(sexp, i, str_R);
  }
  R_PreserveObject(sexp);
  UNPROTECT(1);
  RStatus ^= RINTERF_IDLE;
  return sexp;
}

SEXP
SexpStrVector_new_nofill(int n) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp = NEW_CHARACTER(n);
  if (sexp == NULL) {
    printf("Problem while creating R vector.\n");
    RStatus ^= RINTERF_IDLE;
    return sexp;
  }
  R_PreserveObject(sexp);
  RStatus ^= RINTERF_IDLE;
  return sexp;
}

//FIXME: code duplication with SexpStrVector_new
SEXP
SexpStrVectorMatrix_new(char **v, int nx, int ny) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp = allocMatrix(STRSXP, nx, ny);
  if (sexp == NULL) {
    printf("Problem while creating R vector.\n");
    RStatus ^= RINTERF_IDLE;
    return sexp;
  }
  PROTECT(sexp);
  SEXP str_R;
  int i;
  int n = nx * ny;
  for (i = 0; i < n; i++) {
    str_R = mkChar(v[i]);
    SET_STRING_ELT(sexp, i, str_R);
  }
  R_PreserveObject(sexp);
  UNPROTECT(1);
  RStatus ^= RINTERF_IDLE;
  return sexp;
}

SEXP
SexpIntVector_new(int *v, int n) {
  RINTERF_NEWVECTOR(INTEGER_POINTER, NEW_INTEGER(n), int)
}

SEXP
SexpIntVector_new_nofill(int n) {
  RINTERF_NEWVECTOR_NOFILL(NEW_INTEGER(n))
}

SEXP
SexpIntVectorMatrix_new(int *v, int nx, int ny) {
  int n = nx * ny;
  RINTERF_NEWVECTOR(INTEGER_POINTER, allocMatrix(INTSXP, nx, ny), int)
}

SEXP
SexpIntVectorMatrix_new_nofill(int nx, int ny) {
  RINTERF_NEWVECTOR_NOFILL(allocMatrix(INTSXP, nx, ny))
}

int*
SexpIntVector_ptr(SEXP sexp) {
  return INTEGER_POINTER(sexp);
}


/* Return NULL on failure */
SEXP
SexpBoolVector_new(bool *v, int n) {
  RINTERF_NEWVECTOR(LOGICAL_POINTER, NEW_LOGICAL(n), int)
}

SEXP
SexpBoolVector_new_nofill(int n) {
  RINTERF_NEWVECTOR_NOFILL(NEW_LOGICAL(n))
}

SEXP
SexpBoolVectorMatrix_new(bool *v, int nx, int ny) {
  int n = nx * ny;
  RINTERF_NEWVECTOR(LOGICAL_POINTER, allocMatrix(LGLSXP, nx, ny), int)
}

SEXP
SexpBoolVectorMatrix_new_nofill(int nx, int ny) {
  RINTERF_NEWVECTOR_NOFILL(allocMatrix(LGLSXP, nx, ny))
}


/* Return NULL on failure */
SEXP
SexpVecVector_getitem(const SEXP sexp, const int i) {
  if (TYPEOF(sexp) != VECSXP) {
    printf("Not an R vector of type VECSXP.\n");
    return NULL;
  }
  if ((i < 0) || (i >= LENGTH(sexp))) {
    printf("Out-of-bound.\n");
    /*FIXME: return int or NULL ?*/
    return NULL;
  }
  SEXP sexp_item;
  PROTECT(sexp_item = VECTOR_ELT(sexp, (R_len_t)i));
  R_PreserveObject(sexp_item);
  UNPROTECT(1);
  return sexp_item;
}

/* Return 0 on success, -1 on failure */
int
SexpVecVector_setitem(SEXP sexp, const int i, SEXP value) {
  if (TYPEOF(sexp) != VECSXP) {
    printf("Not an R vector of type VECSXP.\n");
    return -1;
  }
  if (i >= LENGTH(sexp)) {
    printf("Out-of-bound.\n");
    /*FIXME: return int or NULL ?*/
    return -1;
  }
  SET_VECTOR_ELT(sexp, (R_len_t)i, value);
  return 0;
}


/* Return NULL on failure */
SEXP
SexpVecVector_getbyname(const SEXP sexp, char *name) {
  if (TYPEOF(sexp) != VECSXP) {
    printf("Not an R vector of type VECSXP.\n");
    return NULL;
  }
  R_len_t i = nameIndex(sexp, name);
  SEXP sexp_item;
  if (i != R_NaInt) {
    sexp_item = VECTOR_ELT(sexp, i);
    R_PreserveObject(sexp_item);
  } else {
    sexp_item = NULL;
  }
  return sexp_item;
}

/* Return 0 on success, -1 on failure */
int
SexpVecVector_setbyname(SEXP sexp, const char *name, SEXP value) {
  if (TYPEOF(sexp) != VECSXP) {
    printf("Not an R vector of type VECSXP.\n");
    return -1;
  }
  R_len_t i = nameIndex(sexp, name);
  if (i == R_NaInt) {
    return -1;
  } else {
    SET_VECTOR_ELT(sexp, (R_len_t)i, value);
    return 0;
  }
}


/* Return NULL on failure */
SEXP
SexpEnvironment_get(const SEXP envir, const char* symbol) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp, sexp_ok;
  PROTECT(sexp = findVar(Rf_install(symbol), envir));
  if (TYPEOF(sexp) == PROMSXP) {
    sexp_ok = Sexp_evalPromise(sexp);
  } else {
    sexp_ok = sexp;
  }
  //FIXME: protect/unprotect from garbage collection (for now protect only)
  R_PreserveObject(sexp_ok);
  UNPROTECT(1);
  RStatus ^= RINTERF_IDLE;
  return sexp_ok;
}

/* Return NULL on failure */
SEXP
SexpEnvironment_getvalue(const SEXP envir, const char* name) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp, symbol;
  symbol = Rf_install(name);
  PROTECT(sexp = findVarInFrame(envir, symbol));
  //FIXME: protect/unprotect from garbage collection (for now protect only)
  R_PreserveObject(sexp);
  UNPROTECT(1);
  RStatus ^= RINTERF_IDLE;
  return sexp;
}

int
SexpEnvironment_delvalue(const SEXP envir, const char* name) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return -1;
  }
  RStatus ^= RINTERF_IDLE;

  if (envir == R_BaseNamespace) {
    printf("Variables in the R base namespace cannot be changed.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  } else if (envir == R_BaseEnv) {
    printf("Variables in the R base environment cannot be changed.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  } else if (envir == R_EmptyEnv) {
    printf("Nothing can be changed from the empty environment.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  } else if (R_EnvironmentIsLocked(envir)) {
    printf("Variables in a locked environment cannot be changed.\n");
    RStatus ^= RINTERF_IDLE;
    return -1;
  }
  SEXP sexp, symbol;
  symbol = Rf_install(name);
  PROTECT(sexp = findVarInFrame(envir, symbol));
  if (sexp == R_UnboundValue) {
    printf("'%s' not found.\n", name);
    UNPROTECT(1);
    RStatus ^= RINTERF_IDLE;
    return -1;
  }
  SEXP res_rm = librinterface_remove(symbol, envir, R_BaseEnv);
  if (! res_rm) {
    printf("Could not remove the variable '%s' from environment.", name);
    UNPROTECT(1);
    RStatus ^= RINTERF_IDLE;
    return -1;
  }
  UNPROTECT(1);
  RStatus ^= RINTERF_IDLE;
  return 0;
}

int
SexpEnvironment_setvalue(const SEXP envir, const char* name, const SEXP value) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return -1;
  }
  RStatus ^= RINTERF_IDLE;

  SEXP symbol;
  symbol = Rf_install(name);

  //FIXME: is the copy really needed / good ?
  SEXP value_copy;
  PROTECT(value_copy = Rf_duplicate(value));
  Rf_defineVar(symbol, value_copy, envir);
  //FIXME: protect/unprotect from garbage collection (for now protect only)
  UNPROTECT(1);
  RStatus ^= RINTERF_IDLE;
  return 0;
}



/* Return NULL on failure */
SEXP
EmbeddedR_getGlobalEnv(void) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp = R_GlobalEnv;
  //FIXME: protect/unprotect from garbage collection (for now protect only)
  R_PreserveObject(sexp);
  RStatus ^= RINTERF_IDLE;
  return sexp;
}

/* Return NULL on failure */
SEXP
EmbeddedR_getBaseEnv(void) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp = R_BaseEnv;
  //FIXME: protect/unprotect from garbage collection (for now protect only)
  R_PreserveObject(sexp);
  RStatus ^= RINTERF_IDLE;
  return sexp;
}

/* */
static const char*
EmbeddedR_string_from_errmessage(void)
{
  SEXP expr, res;
  /* PROTECT(errMessage_SEXP) */
  PROTECT(expr = allocVector(LANGSXP, 1));
  SETCAR(expr, errMessage_SEXP);
  PROTECT(res = Rf_eval(expr, R_GlobalEnv));
  const char *message = CHARACTER_VALUE(res);
  UNPROTECT(2);
  return message;
}


/* R call.*/
SEXP
Function_call(SEXP fun_R, SEXP *argv, int argc, char **argn, SEXP env) {

  int protect_count = 0;

  /*FIXME: check that fun_R is a function ? */
  SEXP s, t;
  /* List to contain the R call (function + arguments) */
  PROTECT(s = t = allocVector(LANGSXP, argc+1));
  protect_count++;

  /* plug the function in head of the list */
  SETCAR(t, fun_R);
  /* move down the list */
  t = CDR(t);
  /* iterate over the arguments */
  int arg_i;
  char *arg_name;
  for (arg_i = 0; arg_i < argc; arg_i++) {
    SETCAR(t, argv[arg_i]);
    arg_name = argn[arg_i];
    if (strlen(arg_name) > 0) {
      SET_TAG(t, install(arg_name));
    }
    t = CDR(t);
  }
  int errorOccurred = 0;
  SEXP res_R;
  PROTECT(res_R = R_tryEval(s, env, &errorOccurred));
  protect_count++;
  if (errorOccurred) {
    printf("Error: %s.\n", EmbeddedR_string_from_errmessage());
    UNPROTECT(protect_count);
    return NULL;
  }
  SEXP res_ok;
  if (TYPEOF(res_R) == PROMSXP) {
    res_ok = Sexp_evalPromise(res_R);
  } else {
    res_ok = res_R;
  }
  if (errorOccurred) {
    res_R = R_NilValue;
  } else {
    R_PreserveObject(res_ok);
  }
  UNPROTECT(protect_count);
  return res_ok;
}
