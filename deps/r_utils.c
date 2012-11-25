/* Snatched from rpy2 */
#include "r_utils.h"


/* Return R_UnboundValue when not found. */
static SEXP
librinterface_FindFun(SEXP symbol, SEXP rho)
{
    SEXP vl;
    while (rho != R_EmptyEnv) {
        /* This is not really right.  Any variable can mask a function */
        vl = findVarInFrame3(rho, symbol, TRUE);

        if (vl != R_UnboundValue) {
            if (TYPEOF(vl) == PROMSXP) {
                PROTECT(vl);
                vl = eval(vl, rho);
                UNPROTECT(1);
            }
            if (TYPEOF(vl) == CLOSXP || TYPEOF(vl) == BUILTINSXP ||
                TYPEOF(vl) == SPECIALSXP)
               return (vl);

            if (vl == R_MissingArg) {
              printf("R_MissingArg in librinterface_FindFun.\n");
              return R_UnboundValue;
            }
        }
        rho = ENCLOS(rho);
    }
    return R_UnboundValue;
}

SEXP librinterface_remove(SEXP symbol, SEXP env, SEXP rho)
{
  SEXP c_R, call_R, res;

  static SEXP fun_R = NULL;
  /* Only fetch rm() the first time */
  if (fun_R == NULL) {
    PROTECT(fun_R = librinterface_FindFun(install("rm"), rho));
    R_PreserveObject(fun_R);
    UNPROTECT(1);
  }
  if(!isEnvironment(rho)) error("'rho' should be an environment");
  /* incantation to summon R */
  PROTECT(c_R = call_R = allocList(2+1));
  SET_TYPEOF(c_R, LANGSXP);
  SETCAR(c_R, fun_R);
  c_R = CDR(c_R);

  /* first argument is the name of the variable to be removed */
  SETCAR(c_R, symbol);
  //SET_TAG(c_R, install("list"));
  c_R = CDR(c_R);

  /* second argument is the environment in which the variable 
     should be removed  */
  SETCAR(c_R, env);
  SET_TAG(c_R, install("envir"));
  c_R = CDR(c_R);

  int error = 0;
  PROTECT(res = R_tryEval(call_R, rho, &error));

  UNPROTECT(3);
  return res;
}

