#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/sunshine_sleep.sh"

get_connected_dp_outputs() {
        if command -v jq >/dev/null 2>&1; then
                kscreen-doctor -j | jq -r '.outputs[] | select(.name | test("^DP-")) | select(.connected == true) | .name'
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
    if name.startswith("DP-") and output.get("connected") is True:
        print(name)
PY
                return
        fi

        kscreen-doctor -o | awk '/^Output:/{print $2}' | grep '^DP-'
}

dp_enable_args=()
dp_priority_args=()
priority_set=false
while IFS= read -r output; do
        [[ -n "$output" ]] || continue
        dp_enable_args+=( "output.${output}.enable" )
        if [[ "$priority_set" == "false" ]]; then
                dp_priority_args=( "output.${output}.priority.1" )
                priority_set=true
        fi
done < <(get_connected_dp_outputs)

kscreen-doctor \
        "${dp_enable_args[@]}" \
        "${dp_priority_args[@]}" \
        output.HDMI-A-1.disable
