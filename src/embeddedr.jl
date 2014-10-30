# FIXME: have a way to get those declarations from C ?
const NILSXP  = uint(0)
const SYMSXP  = uint(1)
const LISTSXP = uint(2)
const CLOSXP  = uint(3)
const ENVSXP  = uint(4)
const PROMSXP  = uint(5)
const SPECIALSXP = uint(7)
const BUILTINSXP  = uint(8)
const LGLSXP  = uint(10)
const INTSXP  = uint(13)
const REALSXP  = uint(14)
const STRSXP  = uint(16)
const VECSXP  = uint(19)
const EXPRSXP = uint(20)
const S4SXP  = uint(25)


libri = dlopen(Pkg.dir() * "/Rif/deps/librinterface")

function isinitialized()
    res = ccall(dlsym(libri, :EmbeddedR_isInitialized), Int32, ())
    return bool(res)
end

function hasinitargs()
    res = ccall(dlsym(libri, :EmbeddedR_hasArgsSet), Int32, ())
    return bool(res)
end

function isbusy()
    res = ccall(dlsym(libri, :EmbeddedR_isBusy), Int32, ())
    return bool(res)
end

function setinitargs(argv::Array{ASCIIString})
    argv_p = map((x)->pointer(x.data), argv)
    res = ccall(dlsym(libri, :EmbeddedR_setInitArgs), Int32,
                (Int32, Ptr{Ptr{Uint8}}), length(argv), argv_p)
    if res == -1
        if isinitialized()
            error("Initialization can no longer be performed after R was initialized.")
        else
            error("Error while trying to set the initialization parameters.")
        end
    end
end

function getinitargs()
    res = ccall(dlsym(libri, :EmbeddedR_getInitArgs), Void)
    if res == -1
        error("Error while trying to get the initialization parameters.")
    end
end

_default_argv = ["Julia-R", "--slave"]

function initr()
    if ! hasinitargs()
        Rif.setinitargs(_default_argv)
    end
    rhome = rstrip(readall(`R RHOME`))
    print(STDERR, "Using R_HOME=", rhome, "\n")
    EnvHash()["R_HOME"] = rhome
    res = ccall(dlsym(libri, :EmbeddedR_init), Int32, ())
    if res == -1
        if ! hasinitargs()
            error("Initialization parameters must be set before R can be initialized.")
        else
            error("Error while initializing R.")
        end
    end

    return res
end


function R_ProcessEvents()
    res = ccall(dlsym(libri, :EmbeddedR_ProcessEvents), Ptr{Void}, ())
    if res == -1
        error("Error in Process Events")
    end
end

function GUI()
    # start eventloop for non blocking r process
    if isinteractive()
        timeout = Timer((x)-> R_ProcessEvents())
        start_timer(timeout,50e-3,50e-3)
    end
end

macro _RL_INITIALIZED()
    ccall(dlsym(libri, :EmbeddedR_isInitialized), Int32,
          ())
end
