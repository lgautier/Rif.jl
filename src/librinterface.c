/* Copyright - 2012 - Laurent Gautier */
#include <stdlib.h>
#include <strings.h>
#include <R.h>
#include <Rembedded.h>
#include <Rinternals.h>

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
SEXP
Environment_get(const SEXP envir, const char* symbol) {
  if (! RINTERF_ISREADY()) {
    printf("R is not ready.\n");
    return NULL;
  }
  RStatus ^= RINTERF_IDLE;
  SEXP sexp = findVar(install(symbol), envir);
  //FIXME: protect/unprotect from garbage collection (for now protect only)
  R_PreserveObject(sexp);
  RStatus ^= RINTERF_IDLE;
  return sexp;
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

/* Build an R call.*/

/* SEXP */
/* callR(SEXP fun_R) { */
/*   SEXP c_R, call_R; */
/*   int protect_count = 0; */

/*   /\* FIXME: check that fun_R is a function ? *\/ */

/*   PROTECT(c_R = call_R = allocList(nparams+1)); */
/*   protect_count++; */
/*   SET_TYPEOF(call_R, LANGSXP); */
/*   SETCAR(c_R, fun_R); */
/*   c_R = CDR(c_R); */

/*   UNPROTECT(protect_count); */
/* } */

