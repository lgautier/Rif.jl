

base_env = getBaseEnv()

r_paste = get(base_env, "paste")
r_letters = get(base_env, "letters")

res = call(r_paste, r_letters)
@test isequal(26, length(res))
@test isequal("a", res[1])
@test isequal("z", res[26])

res = call(r_paste, r_letters;
           collapse = cR(""))
@test isequal(1, length(res))
@test isequal("abcdefghijklmnopqrstuvwxyz", res[1])
