#!/usr/bin/env python3
"""隔离模拟完整安装流程；所有网络、APT、uv、runuser 调用均由假命令替代。"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SCRATCH = ROOT / '.tmp/python-install-tests'
SCRATCH.mkdir(parents=True, exist_ok=True)
SOURCE = (ROOT / 'basic/python.sh').read_text()
for scenario in ('fresh', 'repeat', 'backup', 'no-stable', 'list-failed', 'download-failed',
                 'python-failed', 'nonroot-failed', 'apt-failed', 'installer-failed',
                 'wrong-path', 'active-venv', 'old-os', 'ubuntu24', 'ubuntu26'):
    with tempfile.TemporaryDirectory(dir=SCRATCH) as directory:
        root = Path(directory)
        commands = root / 'commands'
        defaults = root / 'default-bin'
        commands.mkdir()
        defaults.mkdir()
        (root / 'os-release').write_text('ID=' + ('ubuntu' if scenario.startswith('ubuntu') else 'debian') + '\nVERSION_ID=' +
                                       ({'old-os':'12', 'ubuntu24':'24.04', 'ubuntu26':'26.04'}.get(scenario, '13')) + '\n')
        python_body = f'''#!{sys.executable}
import sys
if '--version' in sys.argv: print('Python 3.14.11')
elif {scenario!r} == 'python-failed': sys.exit(1)
'''
        python_mock = root / 'python-template'
        python_mock.write_text(python_body)
        python_mock.chmod(0o755)
        runtime = root / 'python-root/cpython-3.14.11/bin/python3.14'
        uv_body = f'''#!{sys.executable}
from pathlib import Path
import os, sys, shutil
root=Path({str(root)!r})
runtime=Path({str(runtime)!r})
scenario={scenario!r}
args=sys.argv[1:]
if '--version' in args: print('uv mock'); sys.exit(0)
assert 'UV_PYTHON_INSTALL_MIRROR' not in os.environ
assert os.environ['UV_PYTHON_INSTALL_DIR'] == str(root/'python-root')
if 'list' in args:
    if scenario == 'list-failed': sys.exit(1)
    print('cpython-3.15.0rc2-linux-x86_64-gnu <download available>')
    print('cpython-3.15.0+freethreaded-linux-x86_64-gnu <download available>')
    if scenario != 'no-stable':
        print('cpython-3.14.11-linux-x86_64-gnu <download available>')
        print('cpython-3.14.9-linux-x86_64-gnu <download available>')
elif 'install' in args:
    assert '3.14.11' in args and '--no-bin' in args
    if scenario == 'download-failed': sys.exit(1)
    runtime.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root/'python-template', runtime)
elif 'find' in args:
    assert '--managed-python' in args and '--no-python-downloads' in args
    print('/outside/python' if scenario == 'wrong-path' else runtime)
else: raise RuntimeError(args)
'''
        uv_mock = root / 'uv-template'
        uv_mock.write_text(uv_body)
        uv_mock.chmod(0o755)
        mock = f'''#!{sys.executable}
from pathlib import Path
import os, sys, subprocess
root=Path({str(root)!r})
scenario={scenario!r}
name=Path(sys.argv[0]).name
args=sys.argv[1:]
with (root/'calls').open('a') as f: f.write(name+' '+' '.join(args)+'\\n')
if name=='uname': print('Linux')
elif name=='apt-get':
    if scenario=='apt-failed': sys.exit(100)
elif name=='curl':
    installer = 'exit 1\\n' if scenario=='installer-failed' else 'mkdir -p "$UV_UNMANAGED_INSTALL"\\ncp "'+str(root/'uv-template')+'" "$UV_UNMANAGED_INSTALL/uv"\\ncp "'+str(root/'uv-template')+'" "$UV_UNMANAGED_INSTALL/uvx"\\n'
    Path(args[args.index('-o')+1]).write_text(installer)
elif name=='runuser':
    if scenario=='nonroot-failed': sys.exit(1)
    sys.exit(subprocess.run(args[args.index('--')+1:]).returncode)
elif name=='mv':
    source, target = args[-2:]
    assert source.startswith(str(root)) and target.startswith(str(root))
    os.replace(source, target)
else: raise RuntimeError(name)
'''
        for name in ('uname', 'apt-get', 'curl', 'runuser', 'mv'):
            p = commands / name
            p.write_text(mock)
            p.chmod(0o755)
        if scenario == 'backup':
            (defaults / 'python').write_text('existing executable')
            (defaults / 'python3').symlink_to('/old/missing/python')
        adapted = SOURCE.replace('/etc/os-release', str(root / 'os-release'))
        adapted = adapted.replace('/opt/shtools-python', str(root / 'python-root'))
        adapted = adapted.replace('/usr/local/bin', str(defaults))
        adapted = adapted.replace('/var/backups/shtools-python', str(root / 'backups'))
        adapted = adapted.replace('[[ $EUID -eq 0 ]]', '[[ 0 -eq 0 ]]')
        adapted = adapted.replace('scratch=$(mktemp -d)', f'scratch=$(mktemp -d "{root}/scratch.XXXXXXXX")')
        script = root / 'install.sh'
        script.write_text(adapted)
        env = dict(os.environ, PATH=str(commands)+os.pathsep+str(defaults)+os.pathsep+os.environ['PATH'],
                   VIRTUAL_ENV='active' if scenario == 'active-venv' else '', CONDA_PREFIX='',
                   UV_PYTHON_INSTALL_MIRROR='https://example.invalid')
        success = scenario in ('fresh', 'repeat', 'backup', 'ubuntu24', 'ubuntu26')
        for attempt in range(2 if scenario == 'repeat' else 1):
            result = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True)
            assert (result.returncode == 0) == success, (scenario, result.stdout, result.stderr)
            if success:
                assert (defaults/'python').resolve() == runtime
                assert (defaults/'python3').resolve() == runtime
                assert result.stdout.rstrip().endswith('Python 3.14.11\nPython 3.14.11')
                if scenario == 'backup':
                    backup = next((root/'backups').iterdir())
                    assert (backup/'python').read_text() == 'existing executable'
                    assert os.readlink(backup/'python3') == '/old/missing/python'
            else:
                assert not (defaults/'python3').exists()
        print('PASS:', scenario, flush=True)
print('15 个隔离场景通过，含重复运行；未执行真实 Linux 安装。')
