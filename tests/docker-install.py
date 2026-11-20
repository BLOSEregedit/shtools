#!/usr/bin/env python3
"""隔离模拟安装全流程和下载入口，不访问网络、不安装软件、不修改系统。"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SCRATCH = ROOT / '.tmp' / 'docker-install-tests'
SCRATCH.mkdir(parents=True, exist_ok=True)
MOCK = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name, args = Path(sys.argv[0]).name, sys.argv[1:]
root = Path(os.environ['DOCKER_TEST_ROOT'])
scenario = os.environ['DOCKER_TEST_SCENARIO']
with (root / 'calls').open('a') as f:
    f.write(json.dumps([name, *args]) + '\n')
engine = '30.0.1' if scenario == 'next-major' else '29.10.0'
versions = {'docker-ce': '5:' + engine + '-1~debian.13~trixie',
            'docker-ce-cli': '5:' + engine + '-1~debian.13~trixie',
            'containerd.io': '2.2.1-1~debian.13~trixie',
            'docker-buildx-plugin': '0.31.1-1~debian.13~trixie',
            'docker-compose-plugin': '5.8.0-1~debian.13~trixie'}
if name == 'uname': print('Darwin' if scenario == 'no-linux' else 'Linux')
elif name == 'dpkg':
    if '--print-architecture' in args: print('arm64' if scenario == 'arm64' else 'amd64')
    elif '--compare-versions' in args: sys.exit(0 if scenario == 'downgrade' else 1)
elif name == 'dpkg-query':
    if 'docker.io' in args:
        if scenario == 'conflict': print('docker.io installed')
    elif (root / 'installed').exists() or scenario in ('repeat', 'downgrade'):
        print('0.0.0' if scenario == 'wrong-installed' else versions[args[-1]])
    else: sys.exit(1)
elif name == 'apt-cache':
    assert 'Dir::Etc::sourceparts=-' in args
    assert 'Dir::State::status=/dev/null' in args
    assert 'Dir::Etc::preferences=/dev/null' in args
    if scenario == 'cache-failed': sys.exit(100)
    candidate = versions[args[-1]]
    if scenario == 'none' and args[-1] == 'docker-compose-plugin': candidate = '(none)'
    if scenario == 'beta': candidate = '5:30.0.0~rc.1-1'
    if scenario == 'rc-dash': candidate = '5:30.0.0-rc.1-1'
    if scenario == 'empty': sys.exit(0)
    print('  Candidate: ' + candidate)
    if scenario == 'large':
        for i in range(10000): print('  repository metadata')
elif name in ('curl', 'wget'):
    if scenario in ('key-failed', 'wrapper-download-failed'): sys.exit(22)
    output = Path(args[args.index('-o' if name == 'curl' else '-O') + 1])
    if any('raw.githubusercontent.com' in a for a in args):
        output.write_text('exit 23\n' if scenario == 'wrapper-child-failed' else
                          'printf done > "$DOCKER_TEST_ROOT/child-ran"\n')
    else: output.write_text('mock key')
elif name == 'gpg':
    if scenario == 'gpg-failed': sys.exit(2)
    Path(args[args.index('-o') + 1]).write_text('mock keyring')
elif name == 'apt-get':
    if 'update' in args:
        if scenario == 'update-failed': sys.exit(100)
        if scenario == 'source-failed' and 'Dir::Etc::sourceparts=-' in args: sys.exit(100)
    if 'download' in args:
        assert 'Dir::Etc::sourceparts=-' in args
        if scenario == 'download-failed': sys.exit(100)
        for spec in args[args.index('download') + 1:]:
            package, version = spec.split('=', 1)
            assert versions[package] == version
            if scenario != 'missing-archive' or package != 'docker-compose-plugin':
                Path(package + '_mock.deb').write_text('mock package')
    if 'install' in args:
        assert '--no-remove' in args
        if any(a.endswith('.deb') for a in args):
            if scenario == 'install-failed': sys.exit(100)
            (root / 'installed').touch()
elif name == 'systemctl':
    if scenario == 'service-failed': sys.exit(1)
elif name == 'docker':
    if '--host' in args:
        assert 'unix:///var/run/docker.sock' in args
        print('28.0.0' if scenario == 'runtime-failed' else engine)
    elif args[:2] == ['compose', 'version']:
        if scenario == 'compose-failed': sys.exit(1)
        assert '--short' in args
        print('v2.1.0' if scenario == 'wrong-compose' else 'v5.8.0')
    else: print('Docker mock version')
else: raise RuntimeError(name)
'''

source = (ROOT / 'basic/docker.sh').read_text()
wrapper = (ROOT / 'basic/docker-compose.sh').read_text()
scenarios = ['debian', 'ubuntu24', 'ubuntu26', 'ubuntu-codename', 'arm64', 'repeat',
             'large', 'next-major', 'old-debian', 'old-ubuntu', 'other-os', 'bad-codename',
             'no-linux', 'non-root', 'no-systemd', 'argument', 'conflict', 'custom-source',
             'duplicate-source', 'update-failed', 'key-failed', 'gpg-failed',
             'source-failed', 'cache-failed', 'none', 'empty', 'beta', 'rc-dash', 'downgrade',
             'download-failed', 'missing-archive', 'install-failed', 'wrong-installed',
             'service-failed', 'runtime-failed', 'compose-failed', 'wrong-compose']
successes = set(scenarios[:8])


def prepare(root, scenario):
    bin_dir = root / 'bin'
    bin_dir.mkdir()
    for name in ('uname', 'dpkg', 'dpkg-query', 'apt-cache', 'apt-get', 'curl', 'wget',
                 'gpg', 'systemctl', 'docker'):
        command = bin_dir / name
        command.write_text(MOCK)
        command.chmod(0o755)
    (root / 'etc/apt/sources.list.d').mkdir(parents=True)
    distro, version, codename = 'debian', '13', 'trixie'
    if scenario.startswith('ubuntu') or scenario == 'old-ubuntu':
        distro, version, codename = 'ubuntu', '24.04', 'noble'
    if scenario == 'ubuntu26': version, codename = '26.04', 'resolute'
    if scenario == 'old-debian': version = '12'
    if scenario == 'old-ubuntu': version = '22.04'
    if scenario == 'other-os': distro = 'fedora'
    if scenario == 'bad-codename': codename = ''
    os_release = f'ID={distro}\nVERSION_ID={version}\nVERSION_CODENAME={codename}\nPRETTY_NAME=Mock\n'
    if scenario == 'ubuntu-codename':
        os_release += 'UBUNTU_CODENAME=noble\n'
        os_release = os_release.replace('VERSION_CODENAME=noble', 'VERSION_CODENAME=derivative')
    (root / 'etc/os-release').write_text(os_release)
    if scenario != 'no-systemd': (root / 'run/systemd/system').mkdir(parents=True)
    if scenario == 'custom-source': (root / 'etc/apt/sources.list.d/docker.list').write_text('custom source\n')
    if scenario == 'duplicate-source':
        (root / 'etc/apt/sources.list.d/other.sources').write_text('URIs: https://download.docker.com/linux/debian\n')
    env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
               DOCKER_TEST_ROOT=str(root), DOCKER_TEST_SCENARIO=scenario)
    return env


def adapt(text, root, scenario):
    text = text.replace('/etc/', str(root / 'etc') + '/')
    text = text.replace('/run/systemd/system', str(root / 'run/systemd/system'))
    text = text.replace('/usr/bin/docker', str(root / 'bin/docker'))
    text = text.replace('$EUID -eq 0', '1 -eq 0' if scenario == 'non-root' else '0 -eq 0')
    return text.replace('scratch=$(mktemp -d)', 'scratch=$(mktemp -d "$DOCKER_TEST_ROOT/scratch.XXXXXX")')


for scenario in scenarios:
    with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
        root = Path(directory)
        env = prepare(root, scenario)
        script = root / 'install.sh'
        script.write_text(adapt(source, root, scenario))
        result = subprocess.run(['bash', str(script)] + (['extra'] if scenario == 'argument' else []),
                                env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == (scenario in successes), (scenario, result.stdout, result.stderr)
        calls = [json.loads(line) for line in (root / 'calls').read_text().splitlines()] if (root / 'calls').exists() else []
        assert not any('upgrade' in c or c[0] == 'apt-mark' for c in calls)
        if scenario in successes:
            config = (root / 'etc/apt/sources.list.d/docker.list').read_text()
            distro = 'ubuntu' if scenario.startswith('ubuntu') else 'debian'
            assert f'https://download.docker.com/linux/{distro} ' in config and config.endswith(' stable\n'), config
            if scenario == 'ubuntu-codename': assert ' noble stable' in config
            if scenario == 'arm64': assert 'arch=arm64' in config
            assert any(c[0] == 'docker' and c[1:] == ['compose', 'version', '--short'] for c in calls)
            assert ['systemctl', 'enable', '--now', 'docker'] in calls
            assert '安装完成' in result.stdout
            if scenario == 'repeat':
                rerun = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True)
                assert rerun.returncode == 0, (rerun.stdout, rerun.stderr)
        else:
            assert '安装完成' not in result.stdout
            if scenario not in ('wrong-installed', 'service-failed', 'runtime-failed', 'compose-failed', 'wrong-compose'):
                assert not (root / 'installed').exists(), (scenario, calls)
        if scenario in ('conflict', 'custom-source', 'duplicate-source', 'old-debian', 'old-ubuntu', 'other-os',
                        'bad-codename', 'no-linux', 'non-root', 'no-systemd', 'argument'):
            assert not any(c[0] == 'apt-get' for c in calls), (scenario, calls)
        assert not list(root.glob('scratch.*')), scenario
        print(f'PASS installer: {scenario}')

for scenario in ('wrapper-curl', 'wrapper-wget', 'wrapper-download-failed', 'wrapper-child-failed'):
    with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
        root = Path(directory)
        env = prepare(root, scenario)
        adapted = adapt(wrapper, root, scenario)
        if scenario == 'wrapper-wget': adapted = adapted.replace('if command -v curl >/dev/null; then', 'if false; then')
        script = root / 'entry.sh'
        script.write_text(adapted)
        result = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True)
        expected = {'wrapper-curl': 0, 'wrapper-wget': 0, 'wrapper-download-failed': 22, 'wrapper-child-failed': 23}[scenario]
        assert result.returncode == expected, (scenario, result.stdout, result.stderr)
        assert (root / 'child-ran').exists() == (expected == 0)
        assert not list(root.glob('scratch.*'))
        print(f'PASS entry: {scenario}')

print(f'{len(scenarios) + 4} 个隔离模拟场景通过；未进行 Linux 实机安装。')
