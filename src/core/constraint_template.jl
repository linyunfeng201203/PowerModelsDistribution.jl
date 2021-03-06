"reference angle constraints"
function constraint_mc_theta_ref(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    va_ref = ref(pm, nw, :bus, i, "va")
    constraint_mc_theta_ref(pm, nw, i, va_ref)
end


""
function constraint_mc_slack_power_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_slack_power_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end


""
function constraint_mc_model_voltage(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw)
    constraint_mc_model_voltage(pm, nw)
end


"ohms constraint for branches on the from-side"
function constraint_mc_ohms_yt_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_mc_ohms_yt_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
end


"ohms constraint for branches on the to-side"
function constraint_mc_ohms_yt_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_mc_ohms_yt_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
end


""
function constraint_mc_model_voltage_magnitude_difference(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_mc_model_voltage_magnitude_difference(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end


""
function constraint_mc_model_current(pm::AbstractUBFModels; nw::Int=pm.cnw)
    for (i,branch) in ref(pm, nw, :branch)
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        f_idx = (i, f_bus, t_bus)

        g_sh_fr = branch["g_fr"]
        b_sh_fr = branch["b_fr"]

        constraint_mc_model_current(pm, nw, i, f_bus, f_idx, g_sh_fr, b_sh_fr)
    end
end


""
function constraint_mc_power_losses(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    tm = [1, 1, 1] #TODO

    constraint_mc_power_losses(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end


"Transformer constraints, considering winding type, conductor order, polarity and tap settings."
function constraint_mc_transformer_power(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw, fix_taps::Bool=true)
    if ref(pm, pm.cnw, :conductors)!=3
        Memento.error(_LOGGER, "Transformers only work with networks with three conductors.")
    end

    transformer = ref(pm, :transformer, i)
    f_bus = transformer["f_bus"]
    t_bus = transformer["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)
    config = transformer["configuration"]
    f_cnd = transformer["f_connections"][1:3]
    t_cnd = transformer["t_connections"][1:3]
    tm_set = transformer["tm_set"]
    tm_fixed = fix_taps ? ones(Bool, length(tm_set)) : transformer["tm_fix"]
    tm_scale = calculate_tm_scale(transformer, ref(pm, nw, :bus, f_bus), ref(pm, nw, :bus, t_bus))

    #TODO change data model
    # there is redundancy in specifying polarity seperately on from and to side
    #TODO change this once migrated to new data model
    pol = transformer["polarity"]

    if config == WYE
        constraint_mc_transformer_power_yy(pm, nw, i, f_bus, t_bus, f_idx, t_idx, f_cnd, t_cnd, pol, tm_set, tm_fixed, tm_scale)
    elseif config == DELTA
        constraint_mc_transformer_power_dy(pm, nw, i, f_bus, t_bus, f_idx, t_idx, f_cnd, t_cnd, pol, tm_set, tm_fixed, tm_scale)
    elseif config == "zig-zag"
        Memento.error(_LOGGER, "Zig-zag not yet supported.")
    end
end


"KCL including transformer arcs"
function constraint_mc_power_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_power_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
end


"""
Impose all balance related constraints for which key present in data model of bus.
For a discussion of sequence components and voltage unbalance factor (VUF), see
@INPROCEEDINGS{girigoudar_molzahn_roald-2019,
	author={K. Girigoudar and D. K. Molzahn and L. A. Roald},
	booktitle={submitted},
	title={{Analytical and Empirical Comparisons of Voltage Unbalance Definitions}},
	year={2019},
	month={},
    url={https://molzahn.github.io/pubs/girigoudar_molzahn_roald-2019.pdf}
}
"""
function constraint_mc_bus_voltage_balance(pm::_PM.AbstractPowerModel, bus_id::Int; nw=pm.cnw)
    @assert(ref(pm, nw, :conductors)==3)

    bus = ref(pm, nw, :bus, bus_id)

    if haskey(bus, "vm_vuf_max")
        constraint_mc_bus_voltage_magnitude_vuf(pm, nw, bus_id, bus["vm_vuf_max"])
    end

    if haskey(bus, "vm_seq_neg_max")
        constraint_mc_bus_voltage_magnitude_negative_sequence(pm, nw, bus_id, bus["vm_seq_neg_max"])
    end

    if haskey(bus, "vm_seq_pos_max")
        constraint_mc_bus_voltage_magnitude_positive_sequence(pm, nw, bus_id, bus["vm_seq_pos_max"])
    end

    if haskey(bus, "vm_seq_zero_max")
        constraint_mc_bus_voltage_magnitude_zero_sequence(pm, nw, bus_id, bus["vm_seq_zero_max"])
    end

    if haskey(bus, "vm_ll_min")|| haskey(bus, "vm_ll_max")
        vm_ll_min = haskey(bus, "vm_ll_min") ? bus["vm_ll_min"] : fill(0, 3)
        vm_ll_max = haskey(bus, "vm_ll_max") ? bus["vm_ll_max"] : fill(Inf, 3)
        constraint_mc_bus_voltage_magnitude_ll(pm, nw, bus_id, vm_ll_min, vm_ll_max)
    end
end


"KCL including transformer arcs and load variables."
function constraint_mc_load_power_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_load_power_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
end


"""
CONSTANT POWER
Fixes the load power sd.
sd = [sd_1, sd_2, sd_3]
What is actually fixed, depends on whether the load is connected in delta or wye.
When connected in wye, the load power equals the per-phase power sn drawn at the
bus to which the load is connected.
sd_1 = v_a.conj(i_a) = sn_a

CONSTANT CURRENT
Sets the active and reactive load power sd to be proportional to
the the voltage magnitude.
pd = cp.|vm|
qd = cq.|vm|
sd = cp.|vm| + j.cq.|vm|

CONSTANT IMPEDANCE
Sets the active and reactive power drawn by the load to be proportional to
the square of the voltage magnitude.
pd = cp.|vm|^2
qd = cq.|vm|^2
sd = cp.|vm|^2 + j.cq.|vm|^2

DELTA
When connected in delta, the load power gives the reference in the delta reference
frame. This means
sd_1 = v_ab.conj(i_ab) = (v_a-v_b).conj(i_ab)
We can relate this to the per-phase power by
sn_a = v_a.conj(i_a)
    = v_a.conj(i_ab-i_ca)
    = v_a.conj(conj(s_ab/v_ab) - conj(s_ca/v_ca))
    = v_a.(s_ab/(v_a-v_b) - s_ca/(v_c-v_a))
So for delta, sn is constrained indirectly.
"""
function constraint_mc_load_setpoint(pm::_PM.AbstractPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true)
    load = ref(pm, nw, :load, id)
    bus = ref(pm, nw,:bus, load["load_bus"])

    conn = haskey(load, "configuration") ? load["configuration"] : WYE

    a, alpha, b, beta = _load_expmodel_params(load, bus)

    if conn==WYE
        constraint_mc_load_setpoint_wye(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    else
        constraint_mc_load_setpoint_delta(pm, nw, id, load["load_bus"], a, alpha, b, beta; report=report)
    end
end


"""
DELTA
When connected in delta, the load power gives the reference in the delta reference
frame. This means
sd_1 = v_ab.conj(i_ab) = (v_a-v_b).conj(i_ab)
We can relate this to the per-phase power by
sn_a = v_a.conj(i_a)
    = v_a.conj(i_ab-i_ca)
    = v_a.conj(conj(s_ab/v_ab) - conj(s_ca/v_ca))
    = v_a.(s_ab/(v_a-v_b) - s_ca/(v_c-v_a))
So for delta, sn is constrained indirectly.
"""
function constraint_mc_gen_setpoint(pm::_PM.AbstractPowerModel, id::Int; nw::Int=pm.cnw, report::Bool=true, bounded::Bool=true)
    generator = ref(pm, nw, :gen, id)
    bus = ref(pm, nw,:bus, generator["gen_bus"])

    N = 3
    pmin = get(generator, "pmin", fill(-Inf, N))
    pmax = get(generator, "pmax", fill( Inf, N))
    qmin = get(generator, "qmin", fill(-Inf, N))
    qmax = get(generator, "qmax", fill( Inf, N))

    if get(generator, "configuration", WYE) == WYE
        constraint_mc_gen_setpoint_wye(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    else
        constraint_mc_gen_setpoint_delta(pm, nw, id, bus["index"], pmin, pmax, qmin, qmax; report=report, bounded=bounded)
    end
end


"KCL for load shed problem with transformers"
function constraint_mc_shed_power_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_pd = Dict(k => ref(pm, nw, :load, k, "pd") for k in bus_loads)
    bus_qd = Dict(k => ref(pm, nw, :load, k, "qd") for k in bus_loads)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_shed_power_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
end


"on/off constraint for bus voltages"
function constraint_mc_bus_voltage_on_off(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, kwargs...)
    constraint_mc_bus_voltage_on_off(pm, nw; kwargs...)
end


"on/off voltage magnitude constraint"
function constraint_mc_bus_voltage_magnitude_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)

    constraint_mc_bus_voltage_magnitude_on_off(pm, nw, i, bus["vmin"], bus["vmax"])
end


"on/off voltage magnitude squared constraint for relaxed formulations"
function constraint_mc_bus_voltage_magnitude_sqr_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)

    constraint_mc_bus_voltage_magnitude_sqr_on_off(pm, nw, i, bus["vmin"], bus["vmax"])
end


"This is duplicated at PowerModelsDistribution level to correctly handle the indexing of the shunts."
function constraint_mc_voltage_angle_difference(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    pair = (f_bus, t_bus)

    constraint_mc_voltage_angle_difference(pm, nw, f_idx, branch["angmin"], branch["angmax"])
end


"storage loss constraints, delegate to PowerModels"
function constraint_mc_storage_losses(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw, kwargs...)
    storage = ref(pm, nw, :storage, i)

    _PM.constraint_storage_losses(pm, nw, i, storage["storage_bus"], storage["r"], storage["x"], storage["p_loss"], storage["q_loss"];
        conductors = conductor_ids(pm, nw)
    )
end


"branch thermal constraints from"
function constraint_mc_thermal_limit_from(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if haskey(branch, "rate_a")
        constraint_mc_thermal_limit_from(pm, nw, f_idx, branch["rate_a"])
    end
end


"branch thermal constraints to"
function constraint_mc_thermal_limit_to(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if haskey(branch, "rate_a")
        constraint_mc_thermal_limit_to(pm, nw, t_idx, branch["rate_a"])
    end
end


"voltage magnitude setpoint constraint"
function constraint_mc_voltage_magnitude_only(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw, kwargs...)
    bus = ref(pm, nw, :bus, i)
    vmref = bus["vm"] #Not sure why this is needed
    constraint_mc_voltage_magnitude_only(pm, nw, i, vmref)
end


"generator active power setpoint constraint"
function constraint_mc_gen_power_setpoint_real(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw, kwargs...)
    pg_set = ref(pm, nw, :gen, i)["pg"]
    constraint_mc_gen_power_setpoint_real(pm, nw, i, pg_set)
end


"""
This constraint captures problem agnostic constraints that define limits for
voltage magnitudes (where variable bounds cannot be used)
Notable examples include IVRPowerModel and ACRPowerModel
"""
function constraint_mc_voltage_magnitude_bounds(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    vmin = get(bus, "vmin", fill(0.0, 3)) #TODO update for four-wire
    vmax = get(bus, "vmax", fill(Inf, 3)) #TODO update for four-wire
    constraint_mc_voltage_magnitude_bounds(pm, nw, i, vmin, vmax)
end


""
function constraint_mc_gen_power_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    gen = ref(pm, nw, :gen, i)
    ncnds = length(conductor_ids(pm; nw=nw))

    pmin = get(gen, "pmin", fill(-Inf, ncnds))
    pmax = get(gen, "pmax", fill( Inf, ncnds))
    qmin = get(gen, "qmin", fill(-Inf, ncnds))
    qmax = get(gen, "qmax", fill( Inf, ncnds))

    constraint_mc_gen_power_on_off(pm, nw, i, pmin, pmax, qmin, qmax)
end


""
function constraint_mc_storage_thermal_limit(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = ref(pm, nw, :storage, i)
    constraint_mc_storage_thermal_limit(pm, nw, i, storage["thermal_rating"])
end


""
function constraint_mc_storage_current_limit(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = ref(pm, nw, :storage, i)
    constraint_mc_storage_current_limit(pm, nw, i, storage["storage_bus"], storage["current_rating"])
end


""
function constraint_mc_storage_on_off(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = ref(pm, nw, :storage, i)
    charge_ub = storage["charge_rating"]
    discharge_ub = storage["discharge_rating"]

    cnds = conductor_ids(pm, nw)
    ncnds = length(cnds)
    pmin = zeros(ncnds)
    pmax = zeros(ncnds)
    qmin = zeros(ncnds)
    qmax = zeros(ncnds)

    for c in 1:ncnds
        inj_lb, inj_ub = _PM.ref_calc_storage_injection_bounds(ref(pm, nw, :storage), ref(pm, nw, :bus), c)
        pmin[c] = inj_lb[i]
        pmax[c] = inj_ub[i]
        qmin[c] = max(inj_lb[i], ref(pm, nw, :storage, i, "qmin")[c])
        qmax[c] = min(inj_ub[i], ref(pm, nw, :storage, i, "qmax")[c])
    end

    constraint_mc_storage_on_off(pm, nw, i, pmin, pmax, qmin, qmax, charge_ub, discharge_ub)
end


"defines limits on active power output of a generator where bounds can't be used"
function constraint_mc_gen_active_bounds(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    gen = ref(pm, nw, :gen, i)
    bus = gen["gen_bus"]
    constraint_mc_gen_active_bounds(pm, nw, i, bus, gen["pmax"], gen["pmin"])
end


"defines limits on reactive power output of a generator where bounds can't be used"
function constraint_mc_gen_reactive_bounds(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    gen = ref(pm, nw, :gen, i)
    bus = gen["gen_bus"]
    constraint_mc_gen_reactive_bounds(pm, nw, i, bus, gen["qmax"], gen["qmin"])
end


""
function constraint_mc_load_current_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = ref(pm, nw, :bus, i)
    bus_arcs = ref(pm, nw, :bus_arcs, i)
    bus_arcs_sw = ref(pm, nw, :bus_arcs_sw, i)
    bus_arcs_trans = ref(pm, nw, :bus_arcs_trans, i)
    bus_gens = ref(pm, nw, :bus_gens, i)
    bus_storage = ref(pm, nw, :bus_storage, i)
    bus_loads = ref(pm, nw, :bus_loads, i)
    bus_shunts = ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_mc_load_current_balance(pm, nw, i, bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_loads, bus_gs, bus_bs)
end


""
function constraint_mc_current_from(pm::_PM.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tr, ti = _PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_mc_current_from(pm, nw, f_bus, f_idx, g_fr, b_fr, tr, ti, tm)
end


""
function constraint_mc_current_to(pm::_PM.AbstractIVRModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    tr, ti = _PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    constraint_mc_current_to(pm, nw, t_bus, f_idx, t_idx, g_to, b_to)
end


""
function constraint_mc_bus_voltage_drop(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    tr, ti = _PM.calc_branch_t(branch)
    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]

    constraint_mc_bus_voltage_drop(pm, nw, i, f_bus, t_bus, f_idx, r, x, tr, ti, tm)
end


"ensures that power generation and demand are balanced"
function constraint_mc_network_power_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    comp_bus_ids = ref(pm, nw, :components, i)

    comp_gen_ids = Set{Int64}()
    for bus_id in comp_bus_ids, gen_id in PowerModels.ref(pm, nw, :bus_gens, bus_id)
        push!(comp_gen_ids, gen_id)
    end

    comp_loads = Set()
    for bus_id in comp_bus_ids, load_id in PowerModels.ref(pm, nw, :bus_loads, bus_id)
        push!(comp_loads, PowerModels.ref(pm, nw, :load, load_id))
    end

    comp_shunts = Set()
    for bus_id in comp_bus_ids, shunt_id in PowerModels.ref(pm, nw, :bus_shunts, bus_id)
        push!(comp_shunts, PowerModels.ref(pm, nw, :shunt, shunt_id))
    end

    comp_branches = Set()
    for (branch_id, branch) in PowerModels.ref(pm, nw, :branch)
        if in(branch["f_bus"], comp_bus_ids) && in(branch["t_bus"], comp_bus_ids)
            push!(comp_branches, branch)
        end
    end

    comp_pd = Dict(load["index"] => (load["load_bus"], load["pd"]) for load in comp_loads)
    comp_qd = Dict(load["index"] => (load["load_bus"], load["qd"]) for load in comp_loads)

    comp_gs = Dict(shunt["index"] => (shunt["shunt_bus"], shunt["gs"]) for shunt in comp_shunts)
    comp_bs = Dict(shunt["index"] => (shunt["shunt_bus"], shunt["bs"]) for shunt in comp_shunts)

    comp_branch_g = Dict(branch["index"] => (branch["f_bus"], branch["t_bus"], branch["br_r"], branch["br_x"], branch["tap"], branch["g_fr"], branch["g_to"]) for branch in comp_branches)
    comp_branch_b = Dict(branch["index"] => (branch["f_bus"], branch["t_bus"], branch["br_r"], branch["br_x"], branch["tap"], branch["b_fr"], branch["b_to"]) for branch in comp_branches)

    constraint_mc_network_power_balance(pm, nw, i, comp_gen_ids, comp_pd, comp_qd, comp_gs, comp_bs, comp_branch_g, comp_branch_b)
end
