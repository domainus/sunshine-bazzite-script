#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Get params and set any defaults
width=${1:-3840}
height=${2:-2160}
fps=${3:-120}
hdr=${4:-"false"}

hdr_args=()
if [[ "$hdr" == "true" ]]; then
        hdr_args+=( "output.HDMI-A-1.hdr.enable" )
        hdr_args+=( "output.HDMI-A-1.wcg.enable" )
else
        hdr_args+=( "output.HDMI-A-1.hdr.disable" )
fi

"${SCRIPT_DIR}/sunshine_cancel_sleep.sh"

"${SCRIPT_DIR}/unlock_on_connect.sh"

get_dp_outputs() {
        if command -v jq >/dev/null 2>&1; then
                kscreen-doctor -j | jq -r '.outputs[] | select(.name | test("^DP-")) | .name'
                return
        fi

        if command -v python3 >/dev/null 2>&1; then
                python3 - <<'PY'
import json
import subprocess

data = subprocess.check_output(["kscreen-doctor", "-j"], text=True)
parsed = json.loads(data)
for output in parsed.get("outputs", []):
    name = output.get("name", "")
    if name.startswith("DP-"):
        print(name)
PY
                return
        fi

        kscreen-doctor -o | awk '/^Output:/{print $2}' | grep '^DP-'
}


dp_disable_args=()
while IFS= read -r output; do
        [[ -n "$output" ]] || continue
        dp_disable_args+=( "output.${output}.disable" )
done < <(get_dp_outputs)

kscreen-doctor \
        output.HDMI-A-1.enable \
        output.HDMI-A-1.priority.1 \
        output.HDMI-A-1.mode.${width}x${height}@${fps} \
        "${hdr_args[@]}" \
        "${dp_disable_args[@]}"
