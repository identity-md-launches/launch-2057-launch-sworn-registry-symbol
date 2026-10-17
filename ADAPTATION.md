# Adaptation for the Sepolia launch (rehearsal of mainnet)

## Changes

- **None to executable source or build settings.** `src/`, `lib/`, `foundry.toml`, `remappings.txt`
  are byte-identical to the frozen candidate (baseCommit). Creation code with the brief's arguments
  and runtime code equal the build.
- `test/LaunchManifest.t.sol` (new): deploys Renderer, Composer, then Registry with the brief's exact
  eight arguments on an empty Sepolia-id chain (the constructor's dependency floor) and checks every
  stored address and the name/symbol `Sworn`/`SWORN`. Test only; needed to cover the launch arguments.
- `ADAPTATION.md` (this file).

## Why nothing else changed

- All three constructors are nonpayable, take only static `address` arguments (Registry: 8, others: 0)
  and set no owner; no proxy, initializer, setter, pause, DELEGATECALL, CALLCODE or SELFDESTRUCT.
- The Registry constructor calls dependencies only when they have code; on the empty-chain floor it
  skips them, and live Sepolia reads (audit) show the non-floor checks pass with these arguments.
- Sepolia code-deposit cost above the gas preflight is expected per the brief; code not shrunk.

## Launch order and arguments (for the manifest step)

1. Renderer — no arguments. 2. Composer — no arguments.
3. Registry — curator `0x0919ba50b206c3f31d516de818b1fbc7da21653d`, idmd `0x2c3013c90a1bb65573aae9a7c64fafb82697e4e4`,
   imd `0x44a1cd38474fb1748400e7deb5f8d786cce3f89a`, intake `0xa43e6f75ee006411f79ac1c84120606c2330de82`,
   attester `0x5598aa9146215bc13eb26f2c692ad1461fd32982`, renderer `$contract:Renderer`,
   composer `$contract:Composer`, burnExecutor `0x097A19e0f021BBA5072701132625ad2401043A2E`.

`$owner` is unused: the contracts have no owner roles.

## Imported audit findings

All five reproduce as described or are informational, and every one is a documented design decision
or a residual the brief says not to adapt. None is blocking; none changed code.

- [low] `upgradeSponsored` per-token allowance does not bind, because `claimSponsored` draws the same
  pool: reproduces. Sponsor-pool rules are a design decision; reported only. A fix would need different
  runtime bytes (gate `claimSponsored` or drop the token counter).
- [low] `upgrade()` names community specs by sequence id only, so a front-run `registerSpec` can make
  a claimant pay for another spec: reproduces. A fix (expected spec hash argument) changes the ABI and
  runtime bytes; non-blocking report, left as is. Callers should wait for their `SpecRegistered` event.
- [info] Sepolia relies on the plane signing `chainId 1` for a Sepolia-domain consumer: design decision
  per the brief, covered by existing tests; confirm with the plane before spending TestIMD.
- [info] Preview return words are decoded outside the try: not reachable with the configured executors;
  already recorded in `test/NOTES.md`.
- [info] Coverage note: not a defect.

## Disputed design decisions reported

- The docs' BurnSkipped(1) for exhausted preview gas is a known erratum for V2 (brief); not fixed in code.

## Checks

`forge build` and `forge test --offline` with FOUNDRY_FUZZ_SEED=0x4c2a…5d19: all pass (fork suites
skip without an RPC).
