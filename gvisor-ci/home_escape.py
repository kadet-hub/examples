# rlimits and a private HOME are not filesystem confinement. The code reads
# files outside HOME regardless of where HOME points, and sees RLIMIT values
# that limit resource use, not path visibility.
import os, resource
print("HOME =", os.environ.get("HOME"))
print("RLIMIT_NOFILE =", resource.getrlimit(resource.RLIMIT_NOFILE))
with open("/etc/passwd") as f:
    print("read /etc/passwd ->", f.readline().strip())
