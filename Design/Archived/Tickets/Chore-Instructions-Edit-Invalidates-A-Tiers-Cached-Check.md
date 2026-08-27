# Instructions Edit Invalidates A Tier's Cached Check

Status: untriaged
Filed: 2026-08-27

`survivingTierPrefix` compares whole `TierSpec` values, so editing a tier's `instructions` — a plain
stored string that reaches neither the solve nor validation — drops that tier's cached named-point
result and every later one. Editing the first tier's instructions on a 139-facet pattern therefore
costs a near-full revalidation for a change that moves nothing.
