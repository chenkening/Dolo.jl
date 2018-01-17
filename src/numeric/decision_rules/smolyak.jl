struct SmolyakDR{S<:Grid,T<:SmolyakGrid,nx} <: AbstractDecisionRule{S,T,nx}
    grid_exo::S
    grid_endo::T
    coefs::Vector{Matrix{Float64}}
end

#####
##### 1-argument decision rule
#####

function SmolyakDR(
        grid_exo::S, grid_endo::T, ::Union{Val{nx},Type{Val{nx}}}
    ) where S <: EmptyGrid where T <: SmolyakGrid where nx
    coefs = [Array{Float64}(n_nodes(grid_endo), nx)]
    SmolyakDR{S,T,nx}(grid_exo, grid_endo, coefs)
end

function set_values!(
        dr::SmolyakDR{<:G}, values::Vector{Matrix{Float64}}
    ) where G <: Union{EmptyGrid,UnstructuredGrid}
    for i in 1:length(values)
        A_ldiv_B!(dr.coefs[i], dr.grid_endo.B_nodes, values[i])
    end
end

function set_values!(
        dr::SmolyakDR{<:G,<:SmolyakGrid,nx},
        values::Vector{<:Array{Value{nx}}}
    ) where G <: Union{EmptyGrid,UnstructuredGrid} where nx
    if length(values) != length(dr.coefs)
        msg = "The length of values ($(length(values))) is not the same "
        msg *= "as the length of the coefficient Vector ($(length(dr.coefs)))"
        error(msg)
    end

    for i in 1:length(values)
        N = length(values[i])
        data = reinterpret(Float64, values[i], (nx, N))'
        A_ldiv_B!(dr.coefs[i], dr.grid_endo.B_nodes, data)
    end
end

function evaluate(dr::SmolyakDR{<:EmptyGrid}, z::AbstractMatrix)
    B = BM.evalbase(dr.grid_endo.smol_params, z)
    B*dr.coefs[1]
end

function evaluate(dr::SmolyakDR{<:EmptyGrid,SmolyakGrid{d}}, points::Vector{Point{d}}) where d
    N = length(points)
    mat = reinterpret(Float64, points, (d, N))'
    evaluate(dr, mat)
end

####
#### UnstructuredGrid × CartesianGrid 2 continous arguments d.r.
####

function SmolyakDR(grid_exo::UnstructuredGrid, grid_endo::SmolyakGrid, ::Union{Val{nx},Type{Val{nx}}}) where nx
    coefs = [Array{Float64}(n_nodes(grid_endo), nx) for i in 1:n_nodes(grid_exo)]
    SmolyakDR{typeof(grid_exo),typeof(grid_endo),nx}(grid_exo, grid_endo, coefs)
end

function evaluate(dr::SmolyakDR{<:UnstructuredGrid}, i::Int, z::AbstractMatrix)
    @boundscheck begin
        n_funcs = length(dr.coefs)
        if i > n_funcs
            msg = "Only $n_funcs are known, but function $i was requested"
            throw(BoundsError(msg))
        end
    end
    BM.evalbase(dr.grid_endo.smol_params, z) * dr.coefs[i]
end

function evaluate(dr::SmolyakDR{<:UnstructuredGrid}, i::Int, z::Vector{Point{d}}) where d
    N = length(z)
    mat = reinterpret(Float64, z, (d, N))'
    evaluate(dr, i, mat)
end
