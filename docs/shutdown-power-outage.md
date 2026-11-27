# Full cluster shutdown and power-up

For a planned power outage. Powering the pis off with Longhorn volumes attached leaves them to crash recovery (Postgres replays its WAL, replicas may come back faulted and rebuild), and kubelet's graceful shutdown allows only 30s. So the workloads that use volumes are stopped first, the volumes detach, and only then do the nodes go down.

ArgoCD self-heals every app, so it is paused for the duration; on power-up it restores every replica count from git, so nothing needs remembering.

## Shutdown (human step)

1. Check the cluster is healthy: all nodes `Ready`, every attached volume `healthy`.

   ```shell
   kubectl get nodes
   kubectl -n longhorn-system get volumes.longhorn.io -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUST:.status.robustness,PVC:.status.kubernetesStatus.pvcName
   ```

2. Check no statefulset deletes its PVC when scaled to 0. Every line must show `Retain` for `whenScaled`; a `Delete` there means scaling it down destroys its volume and data.

   ```shell
   kubectl get sts -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,POLICY:.spec.persistentVolumeClaimRetentionPolicy
   ```

3. Pause ArgoCD:

   ```shell
   kubectl -n argocd scale sts argocd-application-controller --replicas=0
   ```

4. Scale every workload that mounts a Longhorn volume to 0. The volume list from step 1 names their PVCs; at the time of writing:

   ```shell
   kubectl -n coder scale sts postgres --replicas=0
   kubectl -n infisical scale sts postgres redis --replicas=0
   kubectl -n observability scale sts loki --replicas=0
   kubectl -n hermes scale deploy hermes --replicas=0
   # the operator reverts a direct scale of its statefulset
   kubectl -n observability patch prometheus prometheus-kube-prometheus-prometheus --type merge -p '{"spec":{"replicas":0}}'
   ```

   Stop any running Coder workspace from the Coder UI.

5. Re-run the volume list from step 1 until every volume is `detached`.
6. Cordon all nodes: `kubectl cordon pi0 pi1 pi2 pi3`
7. Shut down the workers, then pi0 once they no longer answer ping:

   ```shell
   for n in pi1 pi2 pi3; do ssh homekube@$n sudo shutdown -h now; done
   ssh homekube@pi0 sudo shutdown -h now
   ```

8. Wait for the green LEDs to stop, then cut power.

## Power-up (human step)

1. Power the switch, then pi0. Once `kubectl get nodes` answers, power pi1–pi3.
2. When all nodes are `Ready`: `kubectl uncordon pi0 pi1 pi2 pi3`
3. Wait for the Longhorn CSI deployments to be ready (`kubectl -n longhorn-system get deploy`), then unpause ArgoCD:

   ```shell
   kubectl -n argocd scale sts argocd-application-controller --replicas=1
   ```

4. `root-app` has no automated sync: if it shows `OutOfSync` (changes merged while the cluster was down), sync it from the ArgoCD UI.
5. Verify: every Application `Synced`/`Healthy`, every attached volume `healthy`, the workloads from shutdown step 4 back at 1/1.
6. Delete the pre-shutdown pods left in `Error`: `kubectl delete pods -A --field-selector=status.phase=Failed`
