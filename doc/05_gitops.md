# GitOps — ArgoCD

> To be updated when Phase 5 is reached.

## Deploy ArgoCD

```shell
ansible-playbook 06-setup-gitops.yml
```

Deploys ArgoCD via Helm and applies the App-of-Apps root app.

---

## App-of-Apps Structure

### Init Wave (`sync-wave: "-1"`)

- [argocd-config](https://github.com/jangroth/homekube-apps/blob/main/applications/wave-00-init/argocd-config.yaml)
- [longhorn](https://github.com/jangroth/homekube-apps/blob/main/applications/wave-00-init/longhorn.yaml)
- [metrics-server](https://github.com/jangroth/homekube-apps/blob/main/applications/wave-00-init/metrics-server.yaml)

### Apps Wave (`sync-wave: "1"`)

(TBD)
