#!/usr/bin/env python3
"""在隔离目录中替换全部外部安装命令；不连接服务器、不修改系统。"""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SCRATCH = ROOT / '.tmp' / 'pg-install-tests'
SCRATCH.mkdir(parents=True, exist_ok=True)
MOCK = r'''#!/usr/bin/env python3
import os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ['PG_TEST_ROOT'])
major = os.environ['PG_TEST_MAJOR']
scenario = os.environ['PG_TEST_SCENARIO']
version = major + '.6-1.pgdg13+1'
with (root / 'calls').open('a') as f:
    f.write(name + ' ' + ' '.join(args) + '\n')
if name == 'uname': print('Linux')
elif name == 'dpkg':
    if '--print-architecture' in args: print('amd64')
    elif '--compare-versions' in args: sys.exit(0 if scenario == 'downgrade' else 1)
elif name == 'dpkg-query':
    if 'postgresql*' in args:
        if scenario == 'other-major': print('postgresql-16 installed')
        elif scenario == 'meta': print('postgresql installed')
    elif (root / 'installed').exists() or scenario in ('repeat', 'downgrade'):
        print(version)
    else: sys.exit(1)
elif name == 'pg_lsclusters':
    if scenario == 'custom-cluster': print(major + ' custom 5433 online postgres /data /log')
    elif scenario == 'repeat': print(major + ' main 5432 online postgres /data /log')
elif name == 'apt-cache':
    if scenario == 'cache-failed': sys.exit(100)
    candidate = {'none': '(none)', 'wrong-major': '19.1-1.pgdg13+1',
                 'beta': major + 'beta4-1.pgdg13+1', 'distro': major + '.6-1'}.get(scenario, version)
    print('  Candidate: ' + candidate)
    if scenario == 'large':
        for i in range(10000): print('  additional repository metadata')
elif name == 'curl': Path(args[args.index('-o') + 1]).write_text('mock key')
elif name == 'apt-get':
    if scenario == 'source-failed' and any('sourceparts=' in a for a in args): sys.exit(100)
    if 'download' in args:
        assert 'Dir::Etc::sourceparts=-' in args
        for package in ('postgresql-', 'postgresql-client-'):
            Path(package + major + '_mock.deb').write_text('mock package')
    if 'install' in args and any(a.endswith('.deb') for a in args):
        assert '--no-remove' in args
        if scenario == 'install-failed': sys.exit(100)
        (root / 'installed').touch()
        config = root / 'etc' / 'postgresql' / major / 'main'
        config.mkdir(parents=True, exist_ok=True)
        (config / 'postgresql.conf').touch()
        (config / 'start.conf').write_text('auto\n')
elif name == 'systemctl':
    if scenario == 'service-failed' and 'start' in args: sys.exit(1)
elif name == 'runuser':
    if 'SHOW server_version_num' in args:
        print('160006' if scenario == 'wrong-runtime' else str(int(major)*10000 + 6))
    else: print('PostgreSQL ' + version)
else: raise RuntimeError(name)
'''

scripts = [(ROOT / f'basic/PG{v}.sh').read_text() for v in (17, 18)]
assert scripts[0].replace('PG_MAJOR=17', 'PG_MAJOR=18') == scripts[1]
scenarios = ['fresh', 'repeat', 'large', 'other-major', 'meta', 'custom-cluster',
             'cache-failed', 'none', 'wrong-major', 'beta', 'distro', 'downgrade',
             'source-failed', 'install-failed', 'service-failed', 'wrong-runtime']
for major, source in zip((17, 18), scripts):
    for scenario in scenarios:
        with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
            root = Path(directory)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            for name in ('uname', 'dpkg', 'dpkg-query', 'pg_lsclusters', 'apt-cache',
                         'curl', 'apt-get', 'systemctl', 'runuser'):
                command = bin_dir / name
                command.write_text(MOCK)
                command.chmod(0o755)
            (root / 'etc/apt/sources.list.d').mkdir(parents=True)
            (root / 'etc/os-release').write_text('ID=debian\nVERSION_ID=13\nVERSION_CODENAME=trixie\n')
            (root / 'run/systemd/system').mkdir(parents=True)
            adapted = source.replace('/etc/', str(root / 'etc') + '/')
            adapted = adapted.replace('/usr/share/postgresql-common/', str(root / 'share') + '/')
            adapted = adapted.replace('/run/systemd/system', str(root / 'run/systemd/system'))
            adapted = adapted.replace('[[ $EUID -eq 0 ]]', '[[ 0 -eq 0 ]]')
            adapted = adapted.replace('scratch=$(mktemp -d)', 'scratch=$(mktemp -d "$PG_TEST_ROOT/scratch.XXXXXX")')
            script = root / 'install.sh'
            script.write_text(adapted)
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                       PG_TEST_ROOT=str(root), PG_TEST_MAJOR=str(major), PG_TEST_SCENARIO=scenario)
            result = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True)
            expected_success = scenario in ('fresh', 'repeat', 'large')
            assert (result.returncode == 0) == expected_success, (major, scenario, result.stdout, result.stderr)
            calls = (root / 'calls').read_text()
            if scenario in ('other-major', 'meta', 'custom-cluster'):
                assert 'apt-get' not in calls, calls
            if scenario in ('cache-failed', 'none', 'wrong-major', 'beta', 'distro', 'downgrade', 'source-failed'):
                assert not (root / 'installed').exists(), calls
            if expected_success:
                assert f'postgresql@{major}-main' in calls
                assert 'SHOW server_version_num' in calls
                assert ' upgrade' not in calls
                assert ' download ' in calls
            print(f'PASS PG{major}: {scenario}')
print('32 个隔离模拟场景通过；两份脚本仅固定大版本不同。未进行 Linux 实机安装。')
