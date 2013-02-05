
base_env = getBaseEnv()
letters = get(base_env, "letters")
@assert isequal(26, length(letters))

global_env = getGlobalEnv()

