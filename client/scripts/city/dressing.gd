## The small things that make a place lived in (D-281): barrels, crates and sacks by the
## doors, woodpiles, carts, wells and troughs, fences and hedges round yards, shrubs, flower
## beds and fruit trees in the gardens, market stalls on the square, boats at the shore ...
## chosen for each people's way of life and for how grand the place is.
##
## After each settlement is planned Settlements.build calls `decorate`, which dresses the
## buildings placed since the last call (Settlements.placed). Props are model-kit models from
## models/props.gd and models/props_regional.gd, placed with Settlements.prop().
##
## THIS IS A STUB (lead, D-281): it places nothing. The dressing agent replaces it, keeping
## the signature of `decorate`.
extends RefCounted

var s: Settlements   ## the Settlements being built
var _from := 0   ## the first entry of s.placed not yet dressed


func _init(settlements: Settlements) -> void:
	s = settlements


## Dress the settlement just planned: `kind` is "city", "town", "village" or "camp"; `tier`
## its rank (0 village .. 4 metropolis, D-127); `site` the province index (for owner colour).
func decorate(kind: String, tier: int, site: int) -> void:
	_from = s.placed.size()
