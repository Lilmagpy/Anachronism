"""The city of Rome as the 3D client sees it (U7): what stands, and what happens this turn."""

from __future__ import annotations

from typing import Any

from anachronism.engine.city import senate_house
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
        "anachronisms": [a.model_dump() for a in city.anachronisms],
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
