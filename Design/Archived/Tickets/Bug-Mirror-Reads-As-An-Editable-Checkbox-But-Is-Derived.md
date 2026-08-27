# Mirror Reads As An Editable Checkbox But Is Derived From The Stops

Status: untriaged
Filed: 2026-08-26

A tier row's Mirror checkbox is a question asked of the stop list, not a stored field, so on a set that is
already mirror-symmetric by rotation alone — every 8-fold tier seeded at 0, which is most of them —
unchecking it re-expands the same seeds and springs straight back to checked. It looks broken and there is
nothing the author can do with it. Either the control should be disabled and read-only when the answer
cannot change, or mirroring should not be offered as a checkbox at all.
