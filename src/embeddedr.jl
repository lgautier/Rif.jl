# FIXME: have a way to get those declarations from C ?
@compat const NILSXP  = UInt(0)
@compat const SYMSXP  = UInt(1)
@compat const LISTSXP = UInt(2)
@compat const CLOSXP  = UInt(3)
@compat const ENVSXP  = UInt(4)
@compat const PROMSXP  = UInt(5)
@compat const SPECIALSXP = UInt(7)
@compat const BUILTINSXP  = UInt(8)
@compat const LGLSXP  = UInt(10)
@compat const INTSXP  = UInt(13)
@compat const REALSXP  = UInt(14)
@compat const STRSXP  = UInt(16)
@compat const VECSXP  = UInt(19)
@compat const EXPRSXP = UInt(20)
@compat const S4SXP  = UInt(25)


libri = Libdl.dlopen(dirname(@__FILE__) * "/../deps/librinterface")

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
