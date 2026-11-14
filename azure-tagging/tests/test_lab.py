import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('lab', Path(__file__).resolve().parents[1] / 'scripts/lab.py')
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


class LabTests(unittest.TestCase):
    def test_matrix_preserves_quality_and_policy_distinction(self):
        rows = lab.scenarios('261113-abcdef', '2026-11-15')
        keys = ('Application', 'OwnerTeam', 'CostCenter', 'Environment')
        self.assertEqual(12, len(rows))
        self.assertEqual(5, sum(all(row['tags'].get(k, '').strip() for k in keys) for row in rows))
        self.assertEqual(4, sum(row['tags'].get('OwnerTeam', '') == '' for row in rows))
        whitespace = next(r for r in rows if r['scenario'] == 'spaces_owner')
        self.assertEqual('   ', whitespace['tags']['OwnerTeam'])
        self.assertEqual({}, next(r for r in rows if r['scenario'] == 'untagged')['tags'])

    def test_manifest_never_matches_a_foreign_group(self):
        config = {'labId': '261113-abcdef', 'subscriptionId': '00000000-0000-0000-0000-000000000000'}
        ids = lab.expected_ids(config, 'legacy')
        self.assertEqual(4, len(ids))
        self.assertTrue(all('/rg-tagging-demo-261113-abcdef-legacy/' in i for i in ids))
        self.assertTrue(ids.isdisjoint(lab.expected_ids(config, 'production')))

    def test_cleanup_confirmation_fails_before_delete(self):
        config = {'labId': '261113-abcdef', 'subscriptionId': '00000000-0000-0000-0000-000000000000'}
        with patch.object(lab, 'load_config', return_value=(config, {})), patch.object(lab, 'az') as az:
            with self.assertRaises(RuntimeError):
                lab.cleanup(type('Args', (), {'confirm_lab_id': 'different', 'execute': True})())
            az.assert_not_called()


if __name__ == '__main__':
    unittest.main()
