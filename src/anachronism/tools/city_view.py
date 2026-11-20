"""The city of Rome as the 3D client sees it (U7): what stands, and what happens this turn."""

from __future__ import annotations

from dataclasses import asdict
from typing import Any

from anachronism.engine.city import senate_house, work_form
from anachronism.engine.state import GameState


def city_view(state: GameState) -> dict[str, Any] | None:
    """The city's state, or ``None`` outside the Republic scenarios.

    ``monuments`` lists every monument that is not still ``planned`` (absent means not yet
    begun); ``changed`` names those whose ``status`` changed in the latest step.
    """
    city = state.city
    if city is None:
        return None
    return {
        "year": city.year,
        "senate_house": senate_house(state),
        "monuments": [
            {"id": mid, "status": s.state, "years_left": s.years_left}
            for mid, s in sorted(city.standing.items())
            if s.state != "planned"
        ],
        "changed": list(city.changed),
        "anachronisms": [_anachronism(state, a.model_dump()) for a in city.anachronisms],
        "events": [
            {
                "kind": e.kind,
                "year": e.year,
                "ref": e.ref,
                "monument": e.monument,
                "person": e.person,
                "value": e.value,
                "other": e.other,
            }
            for e in city.events
        ],
    }


def _anachronism(state: GameState, work: dict[str, Any]) -> dict[str, Any]:
    """An anachronism with its place in the city and its card (F1 ideas).

    ``form`` is the kit form, site, size and twin from ``engine.city.BUILD_FORMS`` (``None``
    when the city has no form for the kind); ``history`` and ``sources`` come from the idea.
    """
    node = state.tech_nodes.get(work["tech"])
    form = work_form(work["builds"])
    work["form"] = asdict(form) if form is not None else None
    work["history"] = node.history if node is not None else ""
    work["sources"] = [s.split(" # ")[0] for s in node.sources] if node is not None else []
    return work
