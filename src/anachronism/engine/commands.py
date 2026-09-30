"""Applying player and AI actions to the state (validation first, then changes)."""

from __future__ import annotations

from anachronism.content.schema import Stage
from anachronism.engine.actions import (
    Action,
    CancelProject,
    DeclareWar,
    LoggedAction,
    MakePeace,
    PauseProject,
    ProposeAlliance,
    ProposeIdea,
    ResumeProject,
    RuleOnIdea,
    SendEnvoy,
    SetPriority,
    StartProject,
)
from anachronism.engine.diplomacy import apply_diplomacy
from anachronism.engine.judge import apply_ruling
from anachronism.engine.state import GameState, Project
from anachronism.engine.tech import Feasibility, feasibility, propose


def apply_action(state: GameState, action: Action) -> tuple[GameState, LoggedAction]:
    """Apply an action and log it.

    ``state`` itself is unchanged. A rejected action changes nothing except the log, where
    its reason is recorded.
    """
    new = state.model_copy(deep=True)
    ok, message = _apply(new, action)
    logged = LoggedAction(turn=new.turn, action=action, ok=ok, message=message)
    new.action_log.append(logged)
    return new, logged


def describe_blockers(state: GameState, result: Feasibility) -> str:
    """Explain in words what stops a project from starting."""

    def names(ids: tuple[str, ...]) -> str:
        return ", ".join(state.tech_nodes[i].name for i in ids)

    parts = []
    if result.stub:
        parts.append("the idea still needs a proper ruling")
    if result.missing_prerequisites:
        parts.append(f"needs {names(result.missing_prerequisites)} first")
    if result.missing_widespread:
        parts.append(f"needs {names(result.missing_widespread)} to be widespread")
    if result.missing_materials:
        materials = ", ".join(state.world.resources[m].name for m in result.missing_materials)
        parts.append(f"needs access to {materials}")
    return "; ".join(parts)


def _apply(state: GameState, action: Action) -> tuple[bool, str]:
    civ = state.civs.get(action.civ)
    if civ is None:
        return False, f"unknown civilisation {action.civ!r}"
    if isinstance(action, RuleOnIdea):
        return apply_ruling(state, civ.id, action.ruling)
    if isinstance(action, DeclareWar | MakePeace | SendEnvoy | ProposeAlliance):
        return apply_diplomacy(state, action)
    node = state.tech_nodes.get(action.node_id)
    if node is None:
        return False, f"unknown idea {action.node_id!r}"
    known = civ.tech.get(node.id)
    project = civ.projects.get(node.id)

    if isinstance(action, ProposeIdea):
        if known is not None and known.stage.is_adopted:
            return False, f"{node.name} is already in use"
        result = propose(state, civ.id, node.id)
        if result.blocked:
            return True, f"{node.name}: {describe_blockers(state, result)}."
        return True, f"{node.name} could be attempted now."

    if isinstance(action, StartProject):
        if known is not None and known.stage.is_adopted:
            return False, f"{node.name} is already in use"
        if project is not None:
            return False, f"work on {node.name} is already under way"
        result = feasibility(state, civ.id, node.id)
        if result.blocked:
            return False, f"cannot start {node.name}: {describe_blockers(state, result)}"
        propose(state, civ.id, node.id)
        civ.tech[node.id].stage = Stage.EXPERIMENTING
        civ.tech[node.id].goal = False
        civ.projects[node.id] = Project(
            node_id=node.id, started_turn=state.turn, priority=action.priority
        )
        return True, f"Work begins on {node.name}."

    if project is None:
        return False, f"there is no project for {node.name}"
    if isinstance(action, PauseProject):
        if project.paused:
            return False, f"{node.name} is already paused"
        project.paused = True
        return True, f"Work on {node.name} is paused."
    if isinstance(action, ResumeProject):
        if not project.paused:
            return False, f"{node.name} is not paused"
        project.paused = False
        return True, f"Work on {node.name} resumes."
    if isinstance(action, CancelProject):
        del civ.projects[node.id]
        civ.tech[node.id].stage = Stage.CONCEPT
        return True, f"Work on {node.name} is abandoned."
    if isinstance(action, SetPriority):
        project.priority = action.priority
        return True, f"{node.name} now has {action.priority} priority."
    raise AssertionError(f"unhandled action {action!r}")
