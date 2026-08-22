# Validation rebuilds the solid once per tier

Status: untriaged
Filed: 2026-08-22

`validate`'s named-point check intersects the half-spaces of every earlier tier once for each tier that
names a vertex, which costs roughly tiers × planes³. On a generated 139-plane pattern that is 1.65 s
against 0.60 s for the whole solve. An authoring UI that validates after every edit will feel it.
