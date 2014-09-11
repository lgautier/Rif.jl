
base_env = getBaseEnv()
letters = get(base_env, "letters")
@test isequal(26, length(letters))
@test isequal("a", letters[1])
@test isequal("z", letters[26])

global_env = getGlobalEnv()

