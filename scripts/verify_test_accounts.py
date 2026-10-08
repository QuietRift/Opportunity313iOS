#!/usr/bin/env python3
"""Verify standardized fixtures using real Auth sessions and RLS. No secrets saved."""
import argparse
import getpass
import json
from pathlib import Path
import re
import urllib.request
import urllib.error


def verify(project, password):
    config = (project / 'Opportunity313/Core/Supabase/SupabaseManager.swift').read_text()
    base = re.search(r'https://[^"\s]+', config).group()
    key = re.search(r'sb_publishable_[^"\s]+', config).group()
    def request(path, token=None, data=None):
        headers = {'apikey': key, 'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(base + path, None if data is None else json.dumps(data).encode(), headers)
        with urllib.request.urlopen(req, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else None
    youth_ids = {}
    for alias, role in [('child1','youth'),('child2','youth'),('parent','parent'),
                        ('provider','provider'),('admin','admin'),('athletics','athletics')]:
        email = alias + '@opportunity313.com'
        auth = request('/auth/v1/token?grant_type=password', data={'email':email,'password':password})
        token = auth['access_token']
        try:
            uid = auth['user']['id']
            def table(name, query=''):
                return request('/rest/v1/' + name + '?' + query, token)
            assert table('user_roles','select=role&user_id=eq.'+uid) == [{'role':role}], 'Role mismatch'
            assert len(table('profiles','select=user_id&user_id=eq.'+uid)) == 1, 'Missing profile'
            if role == 'youth':
                rows = table('youth_profiles','select=id,user_id,first_name,age_band,account_type&user_id=eq.'+uid)
                assert len(rows) == 1 and rows[0]['account_type'] == 'youth_account'
                assert rows[0]['first_name'] == {'child1':'Kevin','child2':'Sarai'}[alias], 'Wrong child profile'
                assert rows[0]['age_band'] == '9–12', 'Wrong child age band'
                youth_ids[alias] = rows[0]['id']
                assert len(table('youth_profiles','select=id')) == 1, 'Youth can see another profile'
                table('opportunity_saves','select=youth_profile_id&youth_profile_id=eq.'+rows[0]['id'])
            elif role == 'parent':
                links = table('guardian_relationships','select=youth_profile_id&status=eq.active&guardian_user_id=eq.'+uid)
                assert set(youth_ids.values()).issubset({x['youth_profile_id'] for x in links}), 'Family link mismatch'
                for child_id in youth_ids.values():
                    assert len(table('youth_profiles','select=id&id=eq.'+child_id)) == 1, 'Child inaccessible'
                    try:
                        request('/functions/v1/child-access',token,
                                {'action':'generate','youthProfileId':child_id})
                    except urllib.error.HTTPError as error:
                        assert error.code == 400, 'Unexpected child access response'
                    else:
                        raise AssertionError('A direct-login child was given an access code')
            elif role in ('provider','athletics'):
                memberships = table('org_members','select=organization_id&status=eq.active&user_id=eq.'+uid)
                assert len(memberships) == 1
                org = table('organizations','select=id,is_demo,verification_status&id=eq.'+memberships[0]['organization_id'])
                assert len(org) == 1 and org[0]['verification_status'] == 'verified'
                if role == 'athletics':
                    assert org[0]['is_demo']
                if role == 'athletics':
                    request('/rest/v1/rpc/native_ticket_events', token, {'managed_only':True})
                    request('/rest/v1/rpc/native_school_verification_queue', token, {})
            elif role == 'admin':
                request('/rest/v1/rpc/admin_dashboard_stats',token,{})
            table('opportunities','select=id&status=eq.published&limit=1')
            if role != 'admin':
                try:
                    request('/rest/v1/rpc/admin_dashboard_stats',token,{})
                except urllib.error.HTTPError as error:
                    assert error.code in (400,401,403), 'Unexpected authorization response'
                else:
                    raise AssertionError('Non-admin reached admin RPC')
            print('PASS:', email, 'sign-in, role, profile/data access, permissions', flush=True)
        finally:
            request('/auth/v1/logout?scope=local',token,{})
    print('PASS: all six sessions signed out; no content records changed.',flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        verify(args.project,getpass.getpass('Test account password (memory only): '))
    except urllib.error.HTTPError as error:
        print('FAIL: backend HTTP',error.code, error.url.split('/')[3:])
        raise SystemExit(1)
