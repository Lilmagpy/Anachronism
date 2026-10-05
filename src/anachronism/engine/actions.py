"""Actions players and AIs take. Each is logged with its turn so games replay exactly."""

from __future__ import annotations

from enum import StrEnum
from typing import Annotated, Literal

from pydantic import Field

from anachronism.content.schema import Frozen
from anachronism.engine.rulings import Ruling


class Priority(StrEnum):
    """Funding order for projects when resources run short."""

    HIGH = "high"
    NORMAL = "normal"
    LOW = "low"

    @property
    def rank(self) -> int:
        """0 is funded first."""
        return list(Priority).index(self)


class ProposeIdea(Frozen):
    """Consider an idea: it becomes a known concept, and missing prerequisites become goals."""

    kind: Literal["propose"] = "propose"
    civ: str
    node_id: str


class StartProject(Frozen):
    """Commit resources to experimenting with a feasible concept."""

    kind: Literal["start"] = "start"
    civ: str
    node_id: str
    priority: Priority = Priority.NORMAL


class PauseProject(Frozen):
    """Stop funding a project; its progress slowly decays."""

    kind: Literal["pause"] = "pause"
    civ: str
    node_id: str


class HastenProject(Frozen):
    """Pay craftsmen and supplies to push a project on by a turn's work (D-119)."""

    kind: Literal["hasten"] = "hasten"
    civ: str
    node_id: str


class ResumeProject(Frozen):
    """Fund a paused project again."""

    kind: Literal["resume"] = "resume"
    civ: str
    node_id: str


class CancelProject(Frozen):
    """Abandon a project and its progress; the idea stays known as a concept."""

    kind: Literal["cancel"] = "cancel"
    civ: str
    node_id: str


class SetPriority(Frozen):
    """Change the funding order of a project."""

    kind: Literal["priority"] = "priority"
    civ: str
    node_id: str
    priority: Priority


class RuleOnIdea(Frozen):
    """Apply the court's ruling on one of the player's own ideas (DESIGN §8).

    The whole ruling is stored, so replays apply it again without asking any model.
    """

    kind: Literal["ruling"] = "ruling"
    civ: str
    ruling: Ruling


class DeclareWar(Frozen):
    """Go to war with another civilisation."""

    kind: Literal["declare_war"] = "declare_war"
    civ: str
    target: str


class MakePeace(Frozen):
    """Offer peace; accepted if the other side is weary, losing or outmatched.

    ``cede`` also demands every province your armies stand in (D-101): only a side that is
    losing gives up land.
    """

    kind: Literal["peace"] = "peace"
    civ: str
    target: str
    terms: Literal["white", "cede"] = "white"


class SendEnvoy(Frozen):
    """Send an embassy with gifts: eases grudges and warms relations a step."""

    kind: Literal["envoy"] = "envoy"
    civ: str
    target: str


class ProposeAlliance(Frozen):
    """Ask for an alliance: allies join each other's defensive wars."""

    kind: Literal["alliance"] = "alliance"
    civ: str
    target: str


class SendMissionaries(Frozen):
    """Send missionaries of your faith to another court."""

    kind: Literal["missionaries"] = "missionaries"
    civ: str
    target: str


class DemandTribute(Frozen):
    """Demand that a much weaker (or beaten) court become your tributary.

    At war, submission is the price of peace. Tributaries count fully in your trade
    network and stand with you in war.
    """

    kind: Literal["tribute"] = "tribute"
    civ: str
    target: str


class HoldFestival(Frozen):
    """Spend wealth on games and feasts: legitimacy up, unrest down."""

    kind: Literal["festival"] = "festival"
    civ: str


class HireMercenaries(Frozen):
    """Spend wealth on hired soldiers: more military strength for a few turns."""

    kind: Literal["mercenaries"] = "mercenaries"
    civ: str


class Explain(Frozen):
    """Explain the court's new arts to quiet suspicion (DESIGN §7).

    ``divine``: proclaim them a gift of the gods (wealth; believed if legitimacy is high).
    ``sages``: credit foreign sages (knowledge; quiets more, but rivals hear sooner).
    """

    kind: Literal["explain"] = "explain"
    civ: str
    story: Literal["divine", "sages"] = "divine"


class SealBorders(Frozen):
    """Close the borders for a few turns: no trade, and news of your arts travels slowly."""

    kind: Literal["seal"] = "seal"
    civ: str


class SendSpies(Frozen):
    """Pay for a spy network in a rival court (D-115): its plans, its work, its secrets."""

    kind: Literal["spies"] = "spies"
    civ: str
    target: str


class SpreadRumours(Frozen):
    """Pay storytellers: news of your arts already on the road arrives garbled."""

    kind: Literal["rumours"] = "rumours"
    civ: str


class RaiseArmy(Frozen):
    """Call up men from one of your provinces into an army (D-099)."""

    kind: Literal["raise"] = "raise"
    civ: str
    province: str
    size: Literal["small", "medium", "large"] = "medium"
    style: Literal["balanced", "infantry", "missile", "mounted", "siege"] = "balanced"


class MarchArmy(Frozen):
    """Order an army to march to a province (and fight or besiege what it finds)."""

    kind: Literal["march"] = "march"
    civ: str
    army: str
    target: str
    forced: bool = False
    """A forced march: one extra province a turn, at a cost in morale and men."""


class ArmyStance(Frozen):
    """Halt an army in one of three stances.

    ``defend`` meets invaders of your land, ``hold`` stays put, ``pillage`` ravages the enemy
    province it stands in.
    """

    kind: Literal["stance"] = "stance"
    civ: str
    army: str
    stance: Literal["defend", "hold", "pillage"] = "hold"


class ArmyPlan(Frozen):
    """Order the battle plan an army fights with (D-108).

    ``plan`` is a tactic id, or ``auto``: its general chooses.
    """

    kind: Literal["plan"] = "plan"
    civ: str
    army: str
    plan: str = "auto"


class ArmyFormation(Frozen):
    """Order the formation an army draws up in (D-267).

    ``formation`` is a formation id, or ``auto``: its general chooses.
    """

    kind: Literal["formation"] = "formation"
    civ: str
    army: str
    formation: str = "auto"


class ArmyDeploy(Frozen):
    """Order where one kind of soldier stands in an army's line (D-270).

    ``unit_kind`` is a soldier kind (infantry, spear, missile, mounted, elephant);
    ``place`` is ``left``, ``centre``, ``right``, ``reserve``, ``split`` (spread across the
    line) or ``auto`` (the army's formation decides).
    """

    kind: Literal["deploy"] = "deploy"
    civ: str
    army: str
    unit_kind: str
    place: str = "auto"


class ArmyEngage(Frozen):
    """Set an army's rules of engagement (D-267).

    ``fight`` as usual; ``cautious`` withdraws from a battle it expects to lose;
    ``last_man`` never yields.
    """

    kind: Literal["engage"] = "engage"
    civ: str
    army: str
    engage: Literal["fight", "cautious", "last_man"] = "fight"


class Fortify(Frozen):
    """Build (or raise higher) the walls of one of your provinces."""

    kind: Literal["fortify"] = "fortify"
    civ: str
    province: str


class DisbandArmy(Frozen):
    """Send an army home; its men return to the fields."""

    kind: Literal["disband"] = "disband"
    civ: str
    army: str


class ChooseChapter(Frozen):
    """Answer the chapter of history before the court (chronicle mode, D-120)."""

    kind: Literal["chapter"] = "chapter"
    civ: str
    chapter: str
    choice: int


class ChooseDilemma(Frozen):
    """Answer the dilemma put to the court (D-104)."""

    kind: Literal["dilemma"] = "dilemma"
    civ: str
    dilemma: str
    choice: int


class AnswerEnvoy(Frozen):
    """Accept or refuse a rival court's proposal (D-105)."""

    kind: Literal["envoy_answer"] = "envoy_answer"
    civ: str
    accept: bool


class BuildFleet(Frozen):
    """Build warships in a coastal province (D-107)."""

    kind: Literal["build_fleet"] = "build_fleet"
    civ: str
    province: str
    size: Literal["small", "medium", "large"] = "medium"


class Build(Frozen):
    """Raise a building in one of your provinces (D-111).

    If builders are already at work there, it is queued to start next (D-128).
    """

    kind: Literal["build"] = "build"
    civ: str
    province: str
    building: str


class Unqueue(Frozen):
    """Take a building off a province's queue (D-128)."""

    kind: Literal["unqueue"] = "unqueue"
    civ: str
    province: str
    building: str


class SailFleet(Frozen):
    """Order a fleet to sail to a sea."""

    kind: Literal["sail"] = "sail"
    civ: str
    fleet: str
    sea: str


class ScuttleFleet(Frozen):
    """Lay up a fleet: its ships are broken up and cost nothing more."""

    kind: Literal["scuttle"] = "scuttle"
    civ: str
    fleet: str


Orders = (
    RaiseArmy
    | MarchArmy
    | ArmyStance
    | ArmyPlan
    | ArmyFormation
    | ArmyDeploy
    | ArmyEngage
    | DisbandArmy
    | Fortify
    | BuildFleet
    | SailFleet
    | ScuttleFleet
)


Decree = HoldFestival | HireMercenaries | Explain | SealBorders | SpreadRumours | SendSpies


Diplomacy = DeclareWar | MakePeace | SendEnvoy | ProposeAlliance | SendMissionaries | DemandTribute


Action = Annotated[
    ProposeIdea
    | StartProject
    | PauseProject
    | HastenProject
    | ResumeProject
    | CancelProject
    | SetPriority
    | RuleOnIdea
    | DeclareWar
    | MakePeace
    | SendEnvoy
    | ProposeAlliance
    | SendMissionaries
    | DemandTribute
    | HoldFestival
    | HireMercenaries
    | Explain
    | SealBorders
    | SpreadRumours
    | SendSpies
    | RaiseArmy
    | MarchArmy
    | ArmyStance
    | ArmyPlan
    | ArmyFormation
    | ArmyDeploy
    | ArmyEngage
    | DisbandArmy
    | Fortify
    | BuildFleet
    | SailFleet
    | ScuttleFleet
    | Build
    | Unqueue
    | ChooseDilemma
    | ChooseChapter
    | AnswerEnvoy,
    Field(discriminator="kind"),
]


class LoggedAction(Frozen):
    """An action as submitted, with its turn and outcome."""

    turn: int
    action: Action
    ok: bool
    message: str
