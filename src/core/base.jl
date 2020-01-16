
_PMs.ref(pm::_PMs.AbstractPowerModel, nw::Int, key::Symbol, idx, param::String, cnd::Int) = pm.ref[:nw][nw][key][idx][param][cnd]

_PMs.ref(pm::_PMs.AbstractPowerModel, key::Symbol, idx, param::String; nw::Int=pm.cnw, cnd::Int=pm.ccnd) = pm.ref[:nw][nw][key][idx][param][cnd]
