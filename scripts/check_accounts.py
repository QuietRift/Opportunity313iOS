#!/usr/bin/env python3
"""Read-only demo account smoke check. Prompts for a password; never saves it.

Usage: python3 scripts/check_accounts.py --youth-email EMAIL --parent-email EMAIL
       --provider-email EMAIL --admin-email EMAIL
Only authentication/session logout and SELECT requests are sent.
"""
import argparse
import getpass
import json
import re
import urllib.error
import urllib.request
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    roles = ('youth', 'parent', 'provider', 'admin')
    for role in roles:
        parser.add_argument('--' + role + '-email', required=True)
    args = parser.parse_args()
    config = (Path(__file__).resolve().parents[1] / 'Opportunity313/Core/Supabase/SupabaseManager.swift').read_text()
    base = re.search(r'https://[^"\s]+', config).group()
    key = re.search(r'sb_publishable_[^"\s]+', config).group()
    password = getpass.getpass('Demo password (memory only): ')

    def request(path, token=None, data=None):
        headers = {'apikey': key, 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(base + path, None if data is None else json.dumps(data).encode(), headers)
        with urllib.request.urlopen(req, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else None

    for role in roles:
        auth = request('/auth/v1/token?grant_type=password', data={
            'email': getattr(args, role + '_email'), 'password': password
        })
        token = auth['access_token']
        try:
            user_id = auth['user']['id']
            def table(name, query=''):
                return request('/rest/v1/' + name + '?' + query, token)
            assert any(x['role'] == role for x in table('user_roles', 'select=role&user_id=eq.' + user_id)), 'Role mismatch'
            if role == 'youth':
                profiles = table('youth_profiles', 'user_id=eq.' + user_id)
                assert profiles, 'Youth profile missing'
                opportunities = table('opportunities', 'status=eq.published')
                assert opportunities, 'Discovery data missing'
                table('opportunity_saves', 'youth_profile_id=eq.' + profiles[0]['id'])
            elif role == 'parent':
                children = table('guardian_relationships', 'status=eq.active&guardian_user_id=eq.' + user_id)
                assert children, 'Parent child relationship missing'
                for child in children:
                    assert table('youth_profiles', 'id=eq.' + child['youth_profile_id']), 'Child inaccessible'
                    table('opportunity_saves', 'youth_profile_id=eq.' + child['youth_profile_id'])
                table('opportunities', 'status=eq.published')
            elif role == 'provider':
                members = table('org_members', 'status=eq.active&user_id=eq.' + user_id)
                assert members, 'Provider organization membership missing'
                org_id = members[0]['organization_id']
                assert table('organizations', 'id=eq.' + org_id), 'Organization inaccessible'
                assert table('opportunities', 'organization_id=eq.' + org_id), 'Provider submission data missing'
            else:
                table('opportunities', 'status=eq.pending_review')
            print('PASS:', role, 'sign-in, role and core data queries', flush=True)
        finally:
            request('/auth/v1/logout?scope=local', token, {})
    password = None
    print('PASS: all test sessions signed out; no records changed.', flush=True)

if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        print('FAIL: backend HTTP', error.code)
        raise SystemExit(1)
