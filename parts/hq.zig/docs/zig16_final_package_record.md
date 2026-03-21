## Final Package Record

This record captures the current local state of the final GPT package applied to
`parts/hq.zig` on top of `origin/dev` in the `hq.zig.core` worktree.

### Source Context

| item | value |
|---|---|
| upstream thread | `https://chatgpt.com/c/69bb8f96-83d0-83aa-96fc-8cc3d848fa82` |
| local worktree | `/home/nixos/repos/flakes/.worktrees/hq-zig-core` |
| branch | `hq.zig.core` |
| base commit | `9618f340720016e63b3a23721f4fc3a8e71eceaa` |
| package apply mode | `git apply --directory=parts/hq.zig` |

### Artifact Manifest

| artifact | bytes | sha256 |
|---|---:|---|
| `hq-final-from-baseline.diff` | 72288 | `27065fd9c21f74c2c57f1786df9c56dce8d70d9864953283437f81a34a464665` |
| `hq-final-series.patch` | 81417 | `6b812aebd77b5b03d6201101fdeb34eb09c9d3a292b391a50c20557702853bf7` |
| `hq-final-snapshot.tar.gz` | 6019917 | `06997dc652d8c9841ed61cc2ac979c19b8f94e4829f5f07daea8b6c2478033ee` |
| `hq-final-verify.txt` | 7047 | `217b09fd45b3e6d2fa18e6ec7be67dfe3af331194be7bdefce5ba5dc156a9bdd` |
| `hq-final-lineage.txt` | 76 | `8db23229e415922e5ac78b7a05c5fe818dc3164962d54941db1d49cd4c0d8bb0` |

### Integration Facts

| check | result |
|---|---|
| `git apply --check --directory=parts/hq.zig /tmp/hq-gpt-final-artifacts/hq-final-series.patch` | clean |
| `git apply --check --directory=parts/hq.zig /tmp/hq-gpt-final-artifacts/hq-final-from-baseline.diff` | clean |
| final package applied to `parts/hq.zig` | yes |

### Local Confirm Facts

| command | result |
|---|---|
| `zig version` | `0.16.0-dev.2915+065c6e794` |
| `timeout 20s zig build --help -Dhq-suite=unit -Dcdp-root=../chromedevtoolprotocol.zig/src/root.zig` | exit `1`; `invalid option: -Dcdp-root` |
| `timeout 180s zig build test-hq-unit -Dhq-suite=unit -Dcpu=baseline -Dcdp-root=../chromedevtoolprotocol.zig/src/root.zig --summary all` | exit `1`; `invalid option: -Dcdp-root` |
| `timeout 180s zig build test-hq-contract -Dhq-suite=contract -Dcpu=baseline -Dcdp-root=../chromedevtoolprotocol.zig/src/root.zig --summary all` | exit `124`; stdout/stderr empty |
| `timeout 180s zig build test-hq-cli -Dhq-suite=cli -Dcpu=baseline -Dcdp-root=../chromedevtoolprotocol.zig/src/root.zig --summary all` | exit `124`; stdout/stderr empty |

### Interpretation

This commit records an exploratory local-confirm stage.

- The upstream final package is structurally integrable into the `parts/hq.zig`
  subtree.
- The package does not yet transfer cleanly into downstream local green.
- The earliest local mismatch is the `-Dcdp-root` contract on `-Dhq-suite=unit`.
- Contract and CLI paths still hit local timeouts after the package is applied.

This is not a final adoption commit. It is a reproducible record of the current
package, its provenance, and the downstream local facts observed so far.
