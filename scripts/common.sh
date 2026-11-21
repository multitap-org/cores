# Shared by the scripts in this folder (sourced, not run).

repo_root=$(cd "$(dirname "$0")/.." && pwd)

# cfg_get FILE KEY: the value of KEY=value in a core's core.cfg ("" if absent).
cfg_get() {
    sed -n "s/^$2=//p" "$1" | head -n 1
}

# How many compile jobs to run.
jobs_count() {
    nproc 2>/dev/null || echo 4
}

# The file extension of a core on PLATFORM.
lib_ext() {
    case "$1" in
        windows) echo dll ;;
        web)     echo a ;;
        *)       echo so ;;
    esac
}

die() {
    echo "error: $*" >&2
    exit 1
}
