"""Package closure and filesystem tests using explicit mocked import graphs."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('packager',Path(__file__).resolve().parents[1]/'tools/package_windows.py')
pkg=importlib.util.module_from_spec(spec);spec.loader.exec_module(pkg)
class Packaging(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name)
  self.dll=self.root/'dll';self.system=self.root/'system';self.licenses=self.root/'licenses'
  for p in (self.dll,self.system,self.licenses):p.mkdir()
  (self.system/'kernel32.dll').write_bytes(b'system')
  (self.licenses/'SDL2.txt').write_text('Fixture notice')
  self.viewer=self.root/'viewer.exe';self.headless=self.root/'headless.exe'
  self.viewer.write_bytes(b'viewer fixture');self.headless.write_bytes(b'headless fixture')
  for n in ('SDL2.dll','libgcc.dll','libwinpthread.dll'):(self.dll/n).write_bytes(n.encode())
  self.graph={'viewer.exe':['SDL2.dll','KERNEL32.dll'], 'headless.exe':['libgcc.dll'],
              'SDL2.dll':['libgcc.dll'], 'libgcc.dll':['libwinpthread.dll'],
              'libwinpthread.dll':['SDL2.dll','api-ms-win-crt-runtime-l1-1-0.dll']}
  self.output=self.root/'output'
 def imports(self,binary,_):return self.graph[binary.name]
 def run_package(self):
  with patch.object(pkg,'imports',side_effect=self.imports):
   return pkg.package(self.viewer,self.headless,self.dll,self.system,self.licenses,self.output,'objdump','fixture-sha')
 def test_transitive_cycle_and_inventory(self):
  files=self.run_package()
  self.assertEqual([p.name for p in files],['libgcc.dll','libwinpthread.dll','SDL2.dll'])
  info=json.loads((self.output/'build-info.json').read_text())
  self.assertEqual(info['commit'],'fixture-sha')
  self.assertFalse((self.output/'kernel32.dll').exists())
  for name,digest in info['sha256'].items():self.assertEqual(hashlib.sha256((self.output/name).read_bytes()).hexdigest(),digest)
  self.assertEqual((self.output/'VoxelA.exe').read_bytes(),self.viewer.read_bytes())
 def test_missing_transitive_dependency(self):
  (self.dll/'libwinpthread.dll').unlink()
  with self.assertRaisesRegex(FileNotFoundError,'libwinpthread'):self.run_package()
  self.assertFalse(self.output.exists())
 def test_copy_failure_is_atomic(self):
  with patch.object(pkg.shutil,'copy2',side_effect=OSError('simulated copy failure')):
   with self.assertRaises(OSError):self.run_package()
  self.assertFalse(self.output.exists())
  self.assertEqual(list(self.root.glob('voxela-package-*')),[])
 def test_existing_output_is_preserved(self):
  self.output.mkdir();sentinel=self.output/'user-file';sentinel.write_bytes(b'preserve')
  with self.assertRaises(FileExistsError):self.run_package()
  self.assertEqual(sentinel.read_bytes(),b'preserve')
 def test_missing_notices_fail(self):
  (self.licenses/'SDL2.txt').unlink()
  with self.assertRaises(FileNotFoundError):self.run_package()
  self.assertFalse(self.output.exists())
 def test_import_parser_and_architecture(self):
  with patch.object(pkg.subprocess,'check_output',return_value='file format pei-x86-64\n DLL Name: SDL2.dll\n DLL Name: KERNEL32.dll\n'):
   self.assertEqual(pkg.imports(self.viewer,'objdump'),['SDL2.dll','KERNEL32.dll'])
  with patch.object(pkg.subprocess,'check_output',return_value='file format pei-i386'):
   with self.assertRaises(ValueError):pkg.imports(self.viewer,'objdump')
 def test_non_system_copy_wins_over_same_system_name(self):
  (self.system/'SDL2.dll').write_bytes(b'not a portable system dependency')
  self.run_package();self.assertEqual((self.output/'SDL2.dll').read_bytes(),b'SDL2.dll')
if __name__=='__main__':unittest.main()
