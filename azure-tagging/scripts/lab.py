#!/usr/bin/env python3
"""Portable companion lab. No Azure operation occurs on import or prepare."""
import argparse
import csv
import datetime as dt
import io
import json
from pathlib import Path
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / '.lab'
GROUPS = ('development', 'production', 'legacy')
KINDS = ('virtualNetworks', 'networkSecurityGroups', 'routeTables')


def az(*args):
    result = subprocess.run(['az', *args, '--only-show-errors', '-o', 'json'],
                            text=True, capture_output=True, timeout=600)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else None


def save(name, value):
    STATE.mkdir(exist_ok=True)
    (STATE / name).write_text(json.dumps(value, indent=2) + '\n')


def scenarios(lab_id, expires_on):
    cases = (
        ('correct', 'missing_owner', 'missing_cost', 'empty_owner'),
        ('correct', 'spaces_owner', 'wrong_environment', 'old_cost_key'),
        ('wrong_cost', 'untagged', 'missing_owner', 'correct'),
    )
    rows = []
    for group, environment, group_cases in zip(GROUPS, ('dev', 'prod', 'test'), cases):
        for index, case in enumerate(group_cases):
            tags = dict(Application='order-api', OwnerTeam='platform-orders',
                        CostCenter='CC4711', Environment=environment, LabId=lab_id,
                        Purpose='tagging-demo', ExpiresOn=expires_on)
            if case == 'missing_owner': tags.pop('OwnerTeam')
            if case == 'missing_cost': tags.pop('CostCenter')
            if case == 'empty_owner': tags['OwnerTeam'] = ''
            if case == 'spaces_owner': tags['OwnerTeam'] = '   '
            if case == 'wrong_environment': tags['Environment'] = 'Production'
            if case == 'old_cost_key': tags['CostCentre'] = tags.pop('CostCenter')
            if case == 'wrong_cost': tags['CostCenter'] = 'CC9999'
            if case == 'untagged': tags = {}
            name = (f'vnet-{lab_id}-{group}', f'nsg-{lab_id}-{group}-1',
                    f'nsg-{lab_id}-{group}-2', f'rt-{lab_id}-{group}')[index]
            rows.append(dict(group=group, name=name, scenario=case, tags=tags))
    return rows


def expected_ids(config, group):
    prefix = f"/subscriptions/{config['subscriptionId']}/resourceGroups/rg-tagging-demo-{config['labId']}-{group}/providers/Microsoft.Network"
    lab = config['labId']
    return {f'{prefix}/virtualNetworks/vnet-{lab}-{group}'.lower(),
            f'{prefix}/networkSecurityGroups/nsg-{lab}-{group}-1'.lower(),
            f'{prefix}/networkSecurityGroups/nsg-{lab}-{group}-2'.lower(),
            f'{prefix}/routeTables/rt-{lab}-{group}'.lower()}


def prepare(args):
    if (STATE / 'config.json').exists():
        raise RuntimeError('.lab already exists; preserve its manifest and use another checkout for a new lab.')
    subscription = str(uuid.UUID(args.subscription))
    lab = dt.datetime.now(dt.timezone.utc).strftime('%y%m%d') + '-' + uuid.uuid4().hex[:6]
    expires = (dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=2)).date().isoformat()
    config = dict(subscriptionId=subscription, labId=lab, location=args.location,
                  expiresOn=expires, createPolicy=not args.no_policy)
    save('config.json', config)
    save('parameters.json', {
        '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
        'contentVersion': '1.0.0.0',
        'parameters': {k: {'value': v} for k, v in dict(
            labId=lab, expiresOn=expires, location=args.location,
            scenarios=scenarios(lab, expires), createPolicy=config['createPolicy']).items()}})
    query = (ROOT / 'queries/lab.kql').read_text()
    (STATE / 'queries.kql').write_text(query.replace('<SUBSCRIPTION_ID>', subscription).replace('<LAB_ID>', lab))
    print(f'Prepared {lab}. ExpiresOn is a reminder, not automatic cleanup.')


def load_config():
    config = json.loads((STATE / 'config.json').read_text())
    if not re.fullmatch(r'\d{6}-[a-f0-9]{6}', config['labId']):
        raise RuntimeError('Invalid lab ID')
    uuid.UUID(config['subscriptionId'])
    account = az('account', 'show', '--subscription', config['subscriptionId'])
    if account['id'].lower() != config['subscriptionId'].lower():
        raise RuntimeError('Subscription mismatch')
    if config.get('tenantId') and account['tenantId'] != config['tenantId']:
        raise RuntimeError('Tenant mismatch')
    return config, account


def deploy(args):
    config, account = load_config()
    sub = config['subscriptionId']
    watchers = az('network', 'watcher', 'list', '--subscription', sub)
    if not any(w['location'].lower() == config['location'].lower() for w in watchers):
        raise RuntimeError('Choose a region with an existing Network Watcher to avoid automatic creation outside the lab.')
    for group in GROUPS:
        name = f"rg-tagging-demo-{config['labId']}-{group}"
        if az('group', 'exists', '--subscription', sub, '--name', name):
            raise RuntimeError(f'Refusing to reuse existing group {name}')
    definitions = az('policy', 'definition', 'list', '--subscription', sub)
    if any(d['name'] == 'tagging-owner-' + config['labId'] for d in definitions):
        raise RuntimeError('Policy name already exists')
    base = ['--subscription', sub, '--location', config['location'],
            '--name', 'tagging-' + config['labId'], '--template-file', str(ROOT / 'bicep/main.bicep'),
            '--parameters', '@' + str(STATE / 'parameters.json')]
    plan = az('deployment', 'sub', 'what-if', *base)
    save('what-if.json', plan)
    print(f"What-if saved to {STATE / 'what-if.json'}")
    if not args.execute:
        print('No deployment. Review the plan, then repeat with --execute.')
        return
    config['tenantId'] = account['tenantId']
    save('config.json', config)  # keep ownership information even after partial failures
    save('deployment.json', az('deployment', 'sub', 'create', *base))
    print('Deployment complete. Run inspect to collect actual results.')


def inspect(_args):
    config, _ = load_config()
    all_resources = []
    for group in GROUPS:
        name = f"rg-tagging-demo-{config['labId']}-{group}"
        resources = az('resource', 'list', '--subscription', config['subscriptionId'], '--resource-group', name)
        if {r['id'].lower() for r in resources} != expected_ids(config, group):
            raise RuntimeError(f'Inventory differs from the four expected resources in {name}')
        all_resources.extend(resources)
    save('inventory.json', all_resources)
    for index, block in enumerate((STATE / 'queries.kql').read_text().split('// QUERY ')):
        if not block.strip(): continue
        query = block.split('\n', 1)[1]
        result = az('graph', 'query', '--subscriptions', config['subscriptionId'], '--first', '1000', '-q', query)
        save(f'query-{index:02d}.json', result)
        rows = result.get('data', [])
        if rows:
            output = io.StringIO()
            writer = csv.DictWriter(output, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows({k: json.dumps(v, ensure_ascii=False) if isinstance(v, (dict, list)) else v
                              for k, v in row.items()} for row in rows)
            (STATE / f'query-{index:02d}.csv').write_text(output.getvalue())
        print(f'Query {index}: {len(rows)} rows')
    if config['createPolicy']:
        for group in GROUPS:
            name = f"rg-tagging-demo-{config['labId']}-{group}"
            assignment = f"/subscriptions/{config['subscriptionId']}/resourceGroups/{name}/providers/Microsoft.Authorization/policyAssignments/owner-{config['labId']}"
            result = az('policy', 'state', 'list', '--subscription', config['subscriptionId'],
                        '--resource-group', name, '--filter', f"PolicyAssignmentId eq '{assignment}'")
            save(f'policy-{group}.json', result)
            print(f'{group}: {len(result)} policy-state rows; no rows means pending, not compliant.')


def cleanup(args):
    config, _ = load_config()
    if args.confirm_lab_id != config['labId']:
        raise RuntimeError('Confirmation must equal this checkout’s generated lab ID')
    sub = config['subscriptionId']
    for group in GROUPS:
        name = f"rg-tagging-demo-{config['labId']}-{group}"
        rg = az('group', 'show', '--subscription', sub, '--name', name)
        if rg.get('tags', {}).get('LabId') != config['labId'] or rg.get('tags', {}).get('Purpose') != 'tagging-demo':
            raise RuntimeError(f'Ownership tags changed: {name}')
        resources = az('resource', 'list', '--subscription', sub, '--resource-group', name)
        if {r['id'].lower() for r in resources} != expected_ids(config, group):
            raise RuntimeError(f'Unexpected or missing resources: {name}. Review manually.')
        scope = rg['id']
        assignments = az('policy', 'assignment', 'list', '--subscription', sub, '--scope', scope)
        own = f"{scope}/providers/Microsoft.Authorization/policyAssignments/owner-{config['labId']}".lower()
        for assignment in assignments:
            aid = assignment['id'].lower()
            if aid.startswith(scope.lower() + '/') and aid != own:
                raise RuntimeError(f'Additional local assignment found in {name}')
        print('Cleanup target:', name)
    if not args.execute:
        print('No deletion. Repeat with --execute only after reviewing all targets.')
        return
    if config['createPolicy']:
        for group in GROUPS:
            scope = f"/subscriptions/{sub}/resourceGroups/rg-tagging-demo-{config['labId']}-{group}"
            az('policy', 'assignment', 'delete', '--subscription', sub,
               '--name', 'owner-' + config['labId'], '--scope', scope)
        az('policy', 'definition', 'delete', '--subscription', sub, '--name', 'tagging-owner-' + config['labId'])
    for group in GROUPS:
        az('group', 'delete', '--subscription', sub, '--name', f"rg-tagging-demo-{config['labId']}-{group}", '--yes')
    print('Cleanup completed. Subscription deployment history and preexisting Network Watcher are retained.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('prepare')
    p.add_argument('--subscription', required=True)
    p.add_argument('--location', default='northeurope')
    p.add_argument('--no-policy', action='store_true')
    p.set_defaults(func=prepare)
    p = commands.add_parser('deploy'); p.add_argument('--execute', action='store_true'); p.set_defaults(func=deploy)
    p = commands.add_parser('inspect'); p.set_defaults(func=inspect)
    p = commands.add_parser('cleanup')
    p.add_argument('--confirm-lab-id', required=True); p.add_argument('--execute', action='store_true'); p.set_defaults(func=cleanup)
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
