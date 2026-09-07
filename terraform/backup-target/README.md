# backup-target

Creates the S3 bucket and IAM user Longhorn (issue #19) and Velero (issue #21)
use for off-cluster backups. See `docs/specs/008-s3-backup-target-terraform.md`
§4b/§5 in the top-level `homekube` repo for the full design and execution plan.

Applies using the `homekube-terraform` SSO profile created by
`../bootstrap-identity/`.

## Prerequisites

- `../bootstrap-identity/` applied
- `aws sso login --profile homekube-terraform`

## Apply

```shell
cd terraform/backup-target
terraform init
terraform plan
terraform apply
```

Expect 5 resources: S3 bucket, public-access block, lifecycle configuration,
IAM user, IAM access key.

## Verify

```shell
aws s3 ls "s3://$(terraform output -raw bucket_name)" --profile homekube-terraform
terraform output secret_access_key  # sensitive — do not paste into chat/logs
```

Capture `access_key_id` / `secret_access_key` into the target consumer
(Longhorn/Velero secret) directly from `terraform output`. Never commit them.

## Destroy

```shell
terraform destroy
```

Bucket has no `force_destroy` — empty it first if it holds backups you no
longer need.
