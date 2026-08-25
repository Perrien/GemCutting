# Chore Decision Numbers Cited In Code

Status: untriaged
Filed: 2026-08-25

Sixteen source and test files cite decisions by their plan's local numbers — everything under
`CuttingBench/` except `BenchSolid.swift`, which the plan
`3-Cutting-Bench-Pattern-Display-1-Solid-And-Tier-Table` already cleaned up. Those numbers restart at
`D1` in every plan and the plans are archived, so the same citation means different things in different
files and points at documents that are gone. Each should either cite an ADR or state its reason in words,
per the rule in `CLAUDE.md`. Four of them are test files whose citations sit on checks that other plans
pinned as untouchable, so the sweep needs care rather than a regex.
