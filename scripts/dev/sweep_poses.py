"""Write pose files for the visual sweep (client/scripts/urbs/sweep.gd).

  python3 scripts/dev/sweep_poses.py OUT_DIR [--street-step 150] [--air-step 400] [--batch 60]

Writes monuments.json (every standing monument's front), street_NN.json (a grid of eye-height
views inside the Servian circuit and the Campus Martius, two bearings each, in batches) and
air_NN.json (a grid of low aerials looking four ways). Local metres: x east, z south.
"""
import json
import sys
from pathlib import Path


def main() -> None:
    """Write the pose files into the folder given on the command line."""
    out = Path(sys.argv[1])
    args = sys.argv[2:]
    opt = {args[i].lstrip("-"): float(args[i + 1]) for i in range(0, len(args), 2)}
    street_step = opt.get("street-step", 150.0)
    air_step = opt.get("air-step", 400.0)
    batch = int(opt.get("batch", 60))
    out.mkdir(parents=True, exist_ok=True)
    (out / "monuments.json").write_text(json.dumps({"poses": [{"kind": "all_monuments"}]}))
    street = []
    x = -1500.0
    while x <= 1500.0:
        z = -1400.0
        while z <= 1600.0:
            inside_walls = (x - 150) ** 2 / 1300**2 + (z - 100) ** 2 / 1300**2 <= 1.0
            campus = -1200 <= x <= -150 and -1300 <= z <= 300
            if inside_walls or campus:
                for yaw in (45, 225):
                    street.append({"kind": "street", "x": x, "z": z, "yaw": yaw})
            z += street_step
        x += street_step
    for i in range(0, len(street), batch):
        poses = street[i : i + batch]
        (out / f"street_{i // batch:02d}.json").write_text(json.dumps({"poses": poses}))
    air = []
    x = -1600.0
    while x <= 1600.0:
        z = -1600.0
        while z <= 1800.0:
            for yaw in (0, 90, 180, 270):
                air.append({"kind": "air", "x": x, "z": z, "h": 160, "yaw": yaw, "pitch": -32})
            z += air_step
        x += air_step
    for i in range(0, len(air), batch):
        (out / f"air_{i // batch:02d}.json").write_text(json.dumps({"poses": air[i : i + batch]}))
    print(f"{len(street)} street poses, {len(air)} aerial poses in {out}")


if __name__ == "__main__":
    main()
