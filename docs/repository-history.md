# Repository history

`cpu_nano` was extracted from `CPU_DESIGN/final_project` on 2026-10-23.
The original repository remains intact:
[CPU_DESIGN](https://github.com/cameronae/CPU_DESIGN).
Its access permissions remain unchanged.

The extraction used the local `feature/five-stage-cpu` branch, including the
CPU upgrades that had not been pushed to the original GitHub repository.
The original tip was `17244aec945c982bc9fafe01a1215ba0aebc9537`.
The extracted tip, before this documentation update, was
`7b4829b13ad819f7abeca189129f879d6823f3c0`.

A fresh independent clone was filtered with `git-filter-repo` 2.47.0:

```sh
git clone --no-local --single-branch --branch feature/five-stage-cpu /path/to/CPU_DESIGN cpu_nano
cd cpu_nano
git filter-repo --subdirectory-filter final_project
git branch -m main
```

Only the 12 commits affecting `final_project` were retained. Its files now
live directly at this repository's root. The lab folders, parent README,
parent `.DS_Store`, ignored build outputs and unrelated commits are excluded.
The source working directory and its Git history were not rewritten.

Filtering changes commit hashes because paths, trees and parent links change.
All retained commits were verified against the source: author and committer
identities/timestamps and commit messages match, and each extracted commit's
tree exactly equals that original commit's `final_project` tree.
See [the commit mapping](history-map.tsv) for the original and extracted IDs.

The new default branch is `main`. This is an independent GitHub repository,
not a GitHub fork, and does not track the parent repository as a remote.
The documentation update following extraction is a new standalone commit.
