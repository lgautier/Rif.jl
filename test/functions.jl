

base_env = getBaseEnv()

r_paste = get(base_env, "paste")
r_letters = get(base_env, "letters")

res = call(r_paste, [r_letters])
@assert isequal(26, length(res))
@assert isequal("a", res[1])

res = call(r_paste, [r_letters],
           ["collapse"=>cR("")])
@assert isequal(1, length(res))
@assert isequal("abcdefghijklmnopqrstuvwxyz", res[1])
