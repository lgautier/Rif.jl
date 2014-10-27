res_parse = parseR("1+2")
@test isequal(RExpression, typeof(res_parse))

res_eval = evalR(res_parse)
@test isequal(1+2, res_eval[1])    
    
r_env = R("new.env()")

res_eval = evalR(res_parse, r_env)
@test isequal(1+2, res_eval[1])    

res_parse = parseR("x <- 1+2")
res_eval = evalR(res_parse, r_env)
@test isequal(1+2, r_env["x"][1])    
