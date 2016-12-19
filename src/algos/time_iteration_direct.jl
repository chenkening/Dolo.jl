import Dolo


"""
Computes a global solution for a model via backward time iteration.
The time iteration is  applied directly to the decision rule of the model.

# Arguments
* `model::NumericModel`: Model object that describes the current model environment.
* `process::`: The stochastic process associated with the exogenous variables in the model.
* `init_dr::`: Initial guess for the decision rule.
# Returns
* `dr::`: Solved decision rule.
"""
function time_iteration_direct(model, process, init_dr; verbose=true, maxit=100, tol=1e-8)

  # Grid
  gg = model.options.grid
  grid = CartesianGrid(gg.a, gg.b, gg.orders) # temporary compatibility
  endo_nodes = nodes(grid)
  N = size(endo_nodes,1)

  # Discretized exogenous process
  dprocess = discretize(process)
  number_of_smooth_drs(dprocess) = max(n_nodes(dprocess),1)
  nsd = number_of_smooth_drs(dprocess)

  p = model.calibration[:parameters] :: Vector{Float64}

  function stack(x::Array{Array{Float64,2},1})
    return cat(1,x...)
  end
  # initial guess for controls
  x0 = [evaluate(init_dr, i, endo_nodes) for i=1:nsd]
  # set the bound for the controls to check during the iterations not to violate them
  x_lb = Array{Float64,2}[cat(1,[Dolo.controls_lb(model,node(dprocess,i) ,endo_nodes[n,:],p)' for n=1:N]...) for i=1:nsd]
  x_ub = Array{Float64,2}[cat(1,[Dolo.controls_ub(model,node(dprocess,i),endo_nodes[n,:],p)' for n=1:N]...) for i=1:nsd]


  absmax(x) = max([maximum(abs(x[i])) for i=1:length(x)]...)

  # create decision rule (which interpolates x0)
  dr = DecisionRule(process, grid, x0)
  # Define controls of tomorrow
  x1 =[zeros(N,2) for i=1:number_of_smooth_drs(dprocess)]
  # define states of today
  s=deepcopy(endo_nodes);

  # loop option
  it = 0
  err = 1.0

  ###############################   Iteration loop

  while it<maxit && err>tol

    it+=1
    # dr = DecisionRule(process, grid, x0)
    set_values(dr, x0)
    xx0 = stack(x0)
    # Compute expectations function E_f and states of tomorrow
    E_f = [zeros(N,1) for i=1:number_of_smooth_drs(dprocess)]
    S = zeros(size(s))

    for i=1:size(E_f,1)
        m = node(dprocess,i)  ::Vector{Float64}
        for j=1:n_inodes(dprocess,i)
            M = inodes(dprocess,i,j) ::Vector{Float64}
            w = iweights(dprocess,i,j) ::Float64
            # Update the states
            for n=1:N
                S[n,:] = Dolo.transition(model, m, s[n,:], x0[i][n,:], M, p)
            end
            # interpolate controles conditional states of tomorrow
            X = evaluate(dr, i, j, S)
            # Compute expectations as a weited average of the exo states w_j
            for n=1:N
                E_f[i][n,:] += w*Dolo.expectation(model, M, S[n,:], X[n,:], p)
            end
        end
        # compute controles of tomorrow
        for n=1:N
           x1[i][n,:] = Dolo.direct_response(model, m, s[n,:], E_f[i][n,:], p)
        end
    end

    x1 = [max(min(x1[i],x_ub[i]),x_lb[i]) for i in 1:size(x1,1)]

    xx1 = stack(x1)

    # update error
    err = maximum(abs(xx1 - xx0))

    # Update control vector
    x0 = x1

    if verbose
        println("It: ", it, " ; SA: ", err, " ; nit: ", it)
    end
  end
  return dr
end


"""
Computes a global solution for a model via backward time iteration.
The time iteration is applied directly to the decision rule of the model.

If the initial guess for the decision rule is not explicitly provided, the initial guess is provided by `ConstantDecisionRule`.
"""
function time_iteration_direct(model, process::AbstractExogenous; kwargs...)
    init_dr = ConstantDecisionRule(model.calibration[:controls])
    return time_iteration_direct(model, process, init_dr; kwargs...)
end


"""
Computes a global solution for a model via backward time iteration.
The time iteration is applied directly to the decision rule of the model.

If the stochastic process for the model is not explicitly provided, the process is taken from the default provided by the model object, `model.exogenous`
"""
function time_iteration_direct(model, init_dr::AbstractDecisionRule; kwargs...)
    process = model.exogenous
    return time_iteration_direct(model, process, init_dr; kwargs...)
end

"""
Computes a global solution for a model via backward time iteration.
The time iteration is applied directly to the decision rule of the model.

If the stochastic process for the model is not explicitly provided, the process is taken from the default provided by the model object, `model.exogenous`.
Additionally, if the initial guess for the decision rule is not explicitly provided, the initial guess is provided by `ConstantDecisionRule`.
"""
function time_iteration_direct(model; kwargs...)
    process = model.exogenous
    init_dr = ConstantDecisionRule(model.calibration[:controls])
    return time_iteration_direct(model, process, init_dr; kwargs...)
end
