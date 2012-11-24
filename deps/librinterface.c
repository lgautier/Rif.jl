/* Copyright - 2012 - Laurent Gautier */
#include <stdlib.h>
#include <strings.h>
#include <R.h>
#include <Rembedded.h>
#include <Rdefines.h>

/* char *initargv[]= {"JuliaEmbeddedR", "--verbose"}; */
typedef struct {
  int argc;
  char **argv;
} InitArgv;

/* struct { */
/*   list of arguments along their names */
/* } call; */

static InitArgv *initargv = NULL;

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
  int res = Rf_initEmbeddedR(initargv->argc, initargv->argv);
  if (res == 1) {
    RStatus |= (RINTERF_INITIALIZED);
    RStatus ^= RINTERF_IDLE;
    return 0;
  } else {
    printf("R initialization failed.\n"); 
    RStatus ^= RINTERF_IDLE;
   return -1;
  }
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
Sexp_evalPromise(const SEXP sexp) {
  if (TYPEOF(sexp) != PROMSXP) {
    printf("Not a promise.\n");
    return NULL;
  }
  SEXP env, sexp_concrete;
  PROTECT(env = PRENV(sexp));
  PROTECT(sexp_concrete = eval(sexp, env));
  R_PreserveObject(sexp_concrete);
  UNPROTECT(2);
  return sexp_concrete;
}

/* Return NULL on failure */
char* SexpStrVector_getitem(const SEXP sexp, int i) {
  if (TYPEOF(sexp) != STRSXP) {
    printf("Not an R vector of type STRSXP.\n");
    return NULL;
  }
  if (i >= LENGTH(sexp)) {
    printf("Out-of-bound.\n");
    /*FIXME: return int or NULL ?*/
    return NULL;
  }
  char *res;
  SEXP sexp_item = STRING_ELT(sexp, (R_len_t)i);
  cetype_t encoding = Rf_getCharCE(sexp_item);
  switch (encoding) {
  case CE_UTF8:
    res = translateCharUTF8(sexp_item);
    break;
  default:
    res = CHAR(sexp_item);
    break;
  }
  return res;
} 

/* Return -1 on failure */
int SexpStrVector_setitem(const SEXP sexp, int i, char *item) {
  if (TYPEOF(sexp) != STRSXP) {
    printf("Not an R vector of type STRSXP.\n");
    return -1;
  }
  if (i >= LENGTH(sexp)) {
    printf("Out-of-bound.\n");
    /*FIXME: return int or NULL ?*/
    return -1;
  }
  SEXP newstring = mkChar(item);
  SET_STRING_ELT(sexp, (R_len_t)i, newstring);
  return 0;
} 

#define STRINGIFY(x) #x

/* Return 0 on failure (should be NaN) */
#define RINTERF_GETITEM(rpointer, sexptype)		\
  if (TYPEOF(sexp) != sexptype) {			\
  printf("Not an R vector of type %s.\n", STRINGIFY(sexptype)); \
    /*FIXME: return int or NULL ?*/			\
    return 0;						\
  }							\
  if (i >= LENGTH(sexp)) {				\
    printf("Out-of-bound.\n");				\
    /*FIXME: return int or NULL ?*/			\
    return 0;						\
  }							\
  int res = rpointer(sexp)[i];				\
			  return res;			\

double SexpDoubleVector_getitem(const SEXP sexp, int i) {
  RINTERF_GETITEM(NUMERIC_POINTER, REALSXP)
}

int SexpIntVector_getitem(const SEXP sexp, int i) {
  RINTERF_GETITEM(INTEGER_POINTER, INTSXP)
}

int SexpBoolVector_getitem(const SEXP sexp, int i) {
  RINTERF_GETITEM(LOGICAL_POINTER, LGLSXP)
}

#define RINTERF_SETNUMITEM(rpointer, sexptype)		\
  if (TYPEOF(sexp) != sexptype) {			\
    printf("Not an R vector of type %s.\n", STRINGIFY(sexptype));	\
    /*FIXME: return int or NULL ?*/			\
    return -1;						\
  }							\
  if (i >= LENGTH(sexp)) {				\
    printf("Out-of-bound.\n");				\
    /*FIXME: return int or NULL ?*/			\
    return -1;						\
  }							\
  rpointer(sexp)[i] = value;				\
		return 0;				\


int SexpDoubleVector_setitem(const SEXP sexp, int i, double value) {
  RINTERF_SETNUMITEM(NUMERIC_POINTER, REALSXP)
}

int SexpIntVector_setitem(const SEXP sexp, int i, int value) {
  RINTERF_SETNUMITEM(INTEGER_POINTER, INTSXP)
}

int SexpBoolVector_setitem(const SEXP sexp, int i, int value) {
  RINTERF_SETNUMITEM(LOGICAL_POINTER, LGLSXP)
}

SEXP
SexpDoubleVector_new(double *v, int n) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready ready.\n");
    return NULL;
  }
  SEXP sexp = NEW_NUMERIC(n);
  if (sexp == NULL) {
    printf("Problem while creating R vector.\n");
    return sexp;
  }
  PROTECT(sexp);
  double *sexp_p = NUMERIC_POINTER(sexp);
  int i;
  for (i = 0; i < n; i++) {
    sexp_p[i] = v[i];
  }
  R_PreserveObject(sexp);
  UNPROTECT(1);
  return sexp;
}

SEXP
SexpStrVector_new(char **v, int n) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready ready.\n");
    return NULL;
  }
  SEXP sexp = NEW_CHARACTER(n);
  if (sexp == NULL) {
    printf("Problem while creating R vector.\n");
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
  return sexp;
}


SEXP
SexpIntVector_new(int *v, int n) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready ready.\n");
    return NULL;
  }
  SEXP sexp = NEW_INTEGER(n);
  if (sexp == NULL) {
    printf("Problem while creating R vector.\n");
    return sexp;
  }
  PROTECT(sexp);
  int *sexp_p = INTEGER_POINTER(sexp);
  int i;
  for (i = 0; i < n; i++) {
    sexp_p[i] = v[i];
  }
  R_PreserveObject(sexp);
  UNPROTECT(1);
  return sexp;
}

int*
SexpIntVector_ptr(SEXP sexp) {
  return INTEGER_POINTER(sexp); 
}
	
/* /\* Return 0 on failure (should be NaN) *\/ */
/* int */
/* SexpIntVector_getitem(const SEXP sexp, int i) { */
/*   if (TYPEOF(sexp) != INTSXP) { */
/*     printf("Not an R vector of type INTSXP.\n"); */
/*     /\*FIXME: return int or NULL ?*\/ */
/*     return 0; */
/*   } */
/*   if (i >= LENGTH(sexp)) { */
/*     printf("Out-of-bound.\n"); */
/*     /\*FIXME: return int or NULL ?*\/ */
/*     return 0; */
/*   } */
/*   int res = INTEGER_POINTER(sexp)[i]; */
/*   return res; */
/* }  */

/* /\* Return -1 on failure *\/ */
/* int SexpIntVector_setitem(const SEXP sexp, int i, int value) { */
/*   if (TYPEOF(sexp) != INTSXP) { */
/*     printf("Not an R vector of type INTSXP.\n"); */
/*     /\*FIXME: return int or NULL ?*\/ */
/*     return -1; */
/*   } */
/*   if (i >= LENGTH(sexp)) { */
/*     printf("Out-of-bound.\n"); */
/*     /\*FIXME: return int or NULL ?*\/ */
/*     return -1; */
/*   } */
/*   INTEGER_POINTER(sexp)[i] = value; */
/*   return 0; */
/* }  */

SEXP Promise_eval(SEXP sexp) {
  SEXP res, env;
  PROTECT(env = PRENV(sexp));
  PROTECT(res = eval(sexp, env));
  UNPROTECT(1);
  return res;
}

/* Return NULL on failure */
SEXP
Environment_get(const SEXP envir, const char* symbol) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp, sexp_ok;
  PROTECT(sexp = findVar(install(symbol), envir));
  if (TYPEOF(sexp) == PROMSXP) {
    sexp_ok = Promise_eval(sexp);
    UNPROTECT(1);
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

/* R call.*/
SEXP
Function_call(SEXP fun_R, SEXP *argv, int argc, char **argn, SEXP env) {

  int protect_count = 0;

  /*FIXME: check that fun_R is a function ? */

  SEXP s, t;
  PROTECT(t = s = allocList(argc+1));
  protect_count++;
  SET_TYPEOF(s, LANGSXP);
  SETCAR(t, fun_R);
  t = CDR(t);
  int arg_i;
  char *arg_name;
  for (arg_i = 0; arg_i < argc; arg_i++) {
    printf("  arg %i\n", arg_i);
    SETCAR(t, argv[arg_i]);
    printf("    CAR is set\n");
    arg_name = argn[arg_i];
    if (strlen(arg_name) > 0) {
      printf("    Setting name %s\n", arg_name);
      SET_TAG(t, install((char *)(arg_name)));
    }
    printf("    CDR moved\n");
    t = CDR(t);
  }
  int errorOccurred = 0;
  SEXP res_R;
  printf("Calling R.\n");
  PROTECT(res_R = R_tryEval(s, env, &errorOccurred));
  protect_count++;
  printf("  done.\n");
  SEXP res_ok;
  if (TYPEOF(res_R) == PROMSXP) {
    res_ok = Promise_eval(res_R);
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
