# homekube-main

Ansible provisioning for the homekube Raspberry Pi cluster.

See parent `CLAUDE.md` (one level up) for cluster topology, SSH access, and working conventions.

**Agent skills**: use a Matt Pocock skill whenever one covers the task. Its tracker, labels and domain docs (glossary, ADRs) are set in the parent `CLAUDE.md` → `## Agent skills`; in a standalone clone, read it with `gh api repos/jangroth/homekube/contents/CLAUDE.md -H 'Accept: application/vnd.github.raw'`.

---

## Running Playbooks

Run through Task from `homekube-main/`: `task setup` installs Python deps and Ansible collections, `task --list` shows the rest. Playbooks are numbered in run order (10 → 50) for a full cluster build; a fresh or rebuilt pi follows the phases in `README.md`, whose NVMe phase starts with a physical step a human has to do.

Every version lives in `ansible/group_vars/all.yml`, which Renovate owns.

---

## Bootstrap user

Ansible's first connection to a fresh pi is as `boot` (hardcoded in `create_user_account.yml`); provisioning then creates `homekube` and disables password auth, so `boot` only works before phase 3.
