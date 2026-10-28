# homekube-main — nightly todo routine

## Routine settings

| Setting  | Value                                              |
|----------|----------------------------------------------------|
| Schedule | `0 14 * * *` UTC (daily at 14:00 UTC)              |
| Model    | claude-sonnet-4-6 (default)                        |
| Tools    | Default (no extra tool grants required)            |
| Trigger  | `trig_01TrV6VfMXKVEGr9cdMVw4EL` on claude.ai      |

---

## Prompt

You are working on the GitHub repo jangroth/homekube-main. Issues are tracked in a separate repo, jangroth/homekube.

Your task:
1. Fetch open GitHub issues labelled both `agent-safe` and `repo:homekube-main` from the tracker repo using the GitHub MCP tools or REST API.
2. Fetch open PRs in this repo.
3. Exclude any issue that already has an open PR — an issue is in flight if an open PR's branch matches `auto/issue-<number>-*` or its body references the issue (e.g. `Closes jangroth/homekube#<number>` or `#<number>`).
4. From the remaining issues, pick one at random.
5. Create a new branch named `auto/issue-<number>-<slug>`.
6. Implement the fix following the conventions in this repo's CLAUDE.md (playbook sequence, roles, group_vars ownership — note some fixes are docs-only, e.g. filling in stub files under `docs/`).
7. Sanity-check the change: for Ansible changes run `ansible-playbook --syntax-check` on any touched playbook (do not run playbooks for real — no live pi access from this environment); for docs-only changes just proofread/render.
8. Open a PR referencing the issue (include `Closes jangroth/homekube#<number>` in the body so it closes cross-repo), assigned to `jangroth`, marked for human review — do not auto-merge.
9. If no eligible issues are found, exit cleanly with a summary of what was checked.
