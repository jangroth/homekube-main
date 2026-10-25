# Sealed-secrets key: export and restore

Every SealedSecret in `homekube-apps` decrypts only with a key held by the controller in `kube-system`. A rebuilt cluster without those keys cannot decrypt any of them. The keys are not in git and not covered by Longhorn backups.

Automatic key renewal is disabled (`keyrenewperiod: "0"`, [decision 076](https://github.com/jangroth/homekube/blob/main/DECISIONS.md)), so the key set only changes when a key is added by hand. The cluster holds six keys from the earlier 30-day renewals. Existing SealedSecrets stay sealed to whichever key was active when they were sealed, so a backup must contain **every** key with the label, not only the newest.

## Export (human step)

Repeat after any manual rotation (`kubectl -n kube-system get secrets -l sealedsecrets.bitnami.com/sealed-secrets-key` lists the keys and their creation dates).

```shell
kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml | pbcopy
```

Paste into a secure note in the password manager (replace the previous export), then clear the clipboard. Never write it to disk or commit it.

Check the export is complete: the number of `kind: Secret` items in the note equals the number from the `get secrets` command above.

## Restore

On a rebuilt cluster, before the controller starts decrypting (the `sealed-secrets` ArgoCD app creates the controller):

1. Save the note to a temporary file, e.g. `key.yaml` (`chmod 600`).
2. `kubectl apply -f key.yaml`
3. If the controller is already running: `kubectl -n kube-system rollout restart deploy/sealed-secrets` (keys are read at startup).
4. `shred -u key.yaml` (or `rm -P key.yaml` on macOS).
5. Verify: `kubectl get sealedsecrets -A` shows no `Status` errors, and the unsealed Secrets exist (e.g. `kubectl -n longhorn-system get secret longhorn-backup-s3`).

The applied `key.yaml` carries `creationTimestamp`, `resourceVersion` and `uid` fields; if `apply` rejects them, strip those under `metadata`.

## Alternative: re-seal to the newest key

`kubeseal --re-encrypt` rewrites a SealedSecret to the current key, so after re-sealing everything in git only the newest key is needed. Not adopted: it touches every SealedSecret and does not remove the need to back up the key.
