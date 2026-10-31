# Cloud environment

The claude.ai cloud environment the nightly routine runs in. These settings exist only in the environment config on claude.ai; this file records what they should be.

| Setting               | Value                                                   |
|-----------------------|---------------------------------------------------------|
| Name                  | `claude-code-homekube-main`                             |
| Network access        | Custom: only the allowed domains below                  |
| Environment variables | None                                                    |
| Setup script          | `bash /home/user/homekube-main/scripts/cloud/setup.sh`  |

## Allowed domains

```
github.com                            # git clone and push; uv Python downloads
api.github.com                        # gh api calls for issues and PRs
objects.githubusercontent.com         # uv Python downloads (GitHub release assets)
release-assets.githubusercontent.com  # uv Python downloads (GitHub release assets)
astral.sh                             # uv installer, if the image has no uv
pypi.org                              # uv sync
files.pythonhosted.org                # uv sync
galaxy.ansible.com                    # ansible-galaxy collection install
```
