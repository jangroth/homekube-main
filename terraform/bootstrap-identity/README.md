# bootstrap-identity

Creates the IAM Identity Center permission sets and attribution IAM roles that
`../backup-target/` (and future Terraform-managed AWS resources) authenticate
through. See `docs/specs/008-s3-backup-target-terraform.md` §4a/§5 in the
top-level `homekube` repo for the full design and execution plan.

Applied once, by hand, using Jan's admin SSO profile — creating the scoped
identity is itself a privileged action nothing less-privileged can perform.
Every subsequent apply (including `../backup-target/`) uses the
`homekube-terraform` permission set this creates instead.

## Prerequisites

- IAM Identity Center enabled for the account (console, one-time, manual)
- `aws sso login --profile jansso-admin`

## Apply

```shell
cd terraform/bootstrap-identity
terraform init
terraform plan
terraform apply
```

Expect 10 resources: 2 permission sets, 1 inline policy + 1 managed-policy
attachment, 2 account assignments, 2 attribution IAM roles, and their 1 inline
policy + 1 managed-policy attachment.

## Verify

```shell
aws sso login --profile homekube-terraform
aws sso login --profile homekube-readonly
aws sts get-caller-identity --profile homekube-terraform

# Attribution hop — should return assumed-role/homekube-agent-terraform/claude-session
aws sts assume-role \
  --role-arn "$(terraform output -raw agent_terraform_role_arn)" \
  --role-session-name claude-session \
  --profile homekube-terraform
```

## Destroy

```shell
terraform destroy
```

Safe as long as no other Terraform state (e.g. `../backup-target/`) still
depends on the `homekube-terraform` / `homekube-readonly` profiles it removes.
