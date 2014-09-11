# Creating vector via R's c()
vi = Rif.cR(1,2,3)
@test isequal(1, vi[1])
@test isequal(2, vi[2])
@test isequal(3, vi[3])
#@test isequal(3, vi[end])

# Converting Julia array to R and accessing it
vi2 = Int32[1,2,3]
rvi2 = Rif.RArray{Int32,1}(vi2)
@test isequal(1, rvi2[1])
@test isequal(3, rvi2[3])

# Creating via string evaluated in R and then accessed
vf = R("c(4.0,5.0,6.0,7.0)")
@test isequal(4.0, vf[1])
@test isequal(7.0, vf[4])

# Creating matrix via string evaluated in R and then accessed
function test_int_matrix_access(nrows, ncols, colmajor = true)
  ncells = nrows*ncols
  byrowbool = colmajor ? "FALSE" : "TRUE"
  m = R("matrix(1:$ncells, byrow = $byrowbool, nrow = $nrows)")
  for col in 1:ncols
    for row in 1:nrows
      if colmajor
        celli = (col - 1) * nrows + row
      else
        celli = (row - 1) * ncols + col
      end
      @test isequal(celli, m[row, col])
    end
  end
end

for (nrows, ncols) in [(1,2), (2,2), (2,1), (13, 21), (15,9)]
  test_int_matrix_access(nrows, ncols, true)
  test_int_matrix_access(nrows, ncols, false)
end

# Converting Julia matrix to R and accessing it
function test_julia_matrix_conversion_and_access{T <: Number}(m::Matrix{T})
  rm = RArray{Float64,2}(m)
  for r in 1:size(m, 1)
    for c in 1:size(m, 2)
      @test isequal(m[r,c], rm[r,c])
    end
  end
end

test_julia_matrix_conversion_and_access(randn(1,1))
test_julia_matrix_conversion_and_access(randn(2,1))
test_julia_matrix_conversion_and_access(randn(1,2))
test_julia_matrix_conversion_and_access(randn(11,9))
