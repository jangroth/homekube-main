# Ansible Provisioning

> To be written when Phase 3 is reached.

## Playbook sequence

Run from `homekube-main/ansible/` in order:

```shell
ansible-playbook 01-update-control-node.yml
ansible-playbook 02-prepare-pis.yml
```

- `01-update-control-node.yml` — configures darth: SSH config, `/etc/hosts`, tooling
- `02-prepare-pis.yml` — creates `homekube` user, configures base OS on all pis

## Inventory

`inventory/hosts.ini` must use Tailscale hostnames (`pi0`–`pi3`) so playbooks work from any network.

## Vault

Tailscale auth key and other secrets are in `ansible/group_vars/raspberry_pis.yml` (ansible-vault encrypted). Decrypt with:

```shell
ansible-vault decrypt ansible/group_vars/raspberry_pis.yml
```
