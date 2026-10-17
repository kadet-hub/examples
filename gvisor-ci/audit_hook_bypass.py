# A Python audit hook that blocks subprocess is bypassed by calling
# _posixsubprocess.fork_exec directly. fork_exec does not raise the
# "subprocess.Popen" audit event, so the hook never sees the new process.
import sys, os, _posixsubprocess

def hook(event, args):
    if event == "subprocess.Popen":
        raise PermissionError("subprocess blocked by audit hook")
sys.addaudithook(hook)

try:
    import subprocess
    subprocess.run(["/bin/echo", "via subprocess.run"])
except PermissionError as e:
    print("blocked:", e)

errpipe_read, errpipe_write = os.pipe()
pid = _posixsubprocess.fork_exec(
    [b"/bin/echo", b"via", b"fork_exec"], [b"/bin/echo"],
    True, tuple(sorted((errpipe_write,))),
    None, None,
    -1, -1, -1, -1,
    -1, -1,
    errpipe_read, errpipe_write,
    True, False,
    -1, None, None, None, -1,
    None, False)
os.close(errpipe_write)
os.waitpid(pid, 0)
os.close(errpipe_read)
