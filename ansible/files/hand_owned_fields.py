#!/usr/bin/env python3
import json
import re
import subprocess
import sys

KUBECONFIG = sys.argv[1]
KUBECTL_RE = re.compile(
    r'^kubectl(-patch|-edit|-client-side-apply|-replace|-create|-set)?$'
)
EXCLUDED = frozenset([
    'events',
    'events.events.k8s.io',
    'leases.coordination.k8s.io',
    'endpoints',
    'endpointslices.discovery.k8s.io',
])


def kubectl(*args):
    r = subprocess.run(
        ['kubectl', '--kubeconfig', KUBECONFIG] + list(args),
        capture_output=True, text=True,
    )
    return r.returncode, r.stdout


# api-resources exits non-zero if any aggregated API is down but still lists the rest
_, names = kubectl('api-resources', '--verbs=list', '-o', 'name')
kinds = [k for k in names.splitlines() if k and k not in EXCLUDED]
if not kinds:
    sys.exit('api-resources returned no kinds')

hits = []
failed = []
for kind in kinds:
    rc, raw = kubectl('get', kind, '-A', '--show-managed-fields', '-o', 'json')
    try:
        data = json.loads(raw) if rc == 0 else None
    except ValueError:
        data = None
    if data is None:
        failed.append(kind)
        continue
    for item in data.get('items', []):
        meta = item.get('metadata', {})
        ns = meta.get('namespace', '')
        name = meta.get('name', '')
        item_kind = item.get('kind', kind)
        for mf in meta.get('managedFields', []):
            if mf.get('subresource') == 'status':
                continue
            manager = mf.get('manager', '')
            if not KUBECTL_RE.match(manager):
                continue
            fv1 = mf.get('fieldsV1', {})
            owned = []
            for section in [s for s in fv1 if s not in ('f:metadata', 'f:status')]:
                if not fv1[section]:
                    owned.append(section[2:])
                    continue
                for k in fv1[section].keys():
                    if k == '.':
                        continue
                    field = k[2:] if k.startswith('f:') else k
                    owned.append(section[2:] + '.' + field)
            if not owned:
                continue
            time_str = (mf.get('time') or '')[:10]
            ref = (ns + '/' if ns else '') + name
            hits.append('{} {} {} {}: {}'.format(
                item_kind, ref, manager, time_str, ', '.join(owned),
            ))

json.dump({'hits': hits, 'failed': failed}, sys.stdout)
