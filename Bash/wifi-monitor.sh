#!/usr/bin/env bash
#
# wifi-monitor.sh - log Wi-Fi drops on macOS, and work around DHCP renewals that never succeed.
#
# Description: Checks the Wi-Fi link every few seconds and logs each drop with its cause and
#              duration, plus macOS's own Wi-Fi/DHCP log around it. "report" rebuilds the drop
#              history from that system log alone, no monitor needed.
#              "fix-on" is a workaround for networks where the Mac's address renewal never gets
#              an answer (seen with a security product's network filter dropping the renewal
#              retries): Wi-Fi is switched off and on shortly before a short lease runs out,
#              which costs a few seconds instead of minutes without an address.
#              macOS only. No strict mode by design: the loops must survive failing checks.
#              Logs go to $WIFI_MONITOR_DIR (default ~/wifi-monitor), never next to the script.
# Usage:       ./wifi-monitor.sh start        run in the background (keeps the Mac awake)
#              ./wifi-monitor.sh run          run in this terminal, Ctrl+C to stop
#              ./wifi-monitor.sh status       drops so far in the latest run
#              ./wifi-monitor.sh stop         stop the background run and print its summary
#              ./wifi-monitor.sh report [6h]  drop history from macOS's own log (default 24h)
#              ./wifi-monitor.sh fix-on|fix-off|fix-status   the auto-rejoin workaround
#              ./wifi-monitor.sh shortcut     put a "Wi-Fi Fix" app on the Desktop that turns it on/off
# Author:      Sebastian Gräf
# Repo:        https://github.com/segraef/Scripts
#
# Each check names the first failing state:
#   WIFI_DISCONNECTED   not joined to any Wi-Fi network
#   NO_IP_ADDRESS       joined, but no address from DHCP (or a self-assigned 169.254.x)
#   ROUTER_UNREACHABLE  has an address, but neither the router nor the internet answers
#   INTERNET_DOWN       router answers, internet does not (problem upstream of the router)
#   WEB_FAILING         internet answers ping, a web page does not load (DNS or a login page)
# A run writes run-<start time>/ with samples.csv (one row per check), events.log (one line
# per state change, with how long each drop lasted) and syslog-*.txt (system log per drop).

IF=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2; exit}')
BASE="${WIFI_MONITOR_DIR:-$HOME/wifi-monitor}"
mkdir -p "$BASE"
PIDFILE="$BASE/monitor.pid"
INTERVAL=2         # seconds between checks
REJOIN_EARLY=150   # fix: rejoin this many seconds before the lease ends
MAX_LEASE=3600     # fix: only act on leases this short; normal multi-hour leases are left alone

note() { echo "$(date '+%F %T')  $*" | tee -a "$EV"; }

ms() {  # round-trip ms of one ping, empty if no reply
    ping -n -c1 -t1 "$1" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p'
}

router_ok() {  # many routers ignore ping, so an open DNS port counts as an answer too
    [ -n "$1" ] && { nc -z -G1 -w1 "$1" 53 >/dev/null 2>&1 || ping -n -c1 -t1 "$1" >/dev/null 2>&1; }
}

lease_age_min() {
    local s
    s=$(ipconfig getsummary "$IF" 2>/dev/null | awk -F' : ' '/LeaseStartTime/{print $2; exit}')
    [ -n "$s" ] && s=$(date -j -f '%m/%d/%Y %H:%M:%S' "$s" +%s 2>/dev/null) && echo $(( ($(date +%s) - s) / 60 ))
}

evidence() {  # $1 run dir, $2 epoch the drop started; grabs 35 min back to cover a whole short lease
    /usr/bin/log show --start "$(date -r $(($2 - 2100)) '+%F %T')" --style compact --predicate \
        "(process == \"configd\" AND subsystem == \"com.apple.IPConfiguration\" AND eventMessage CONTAINS \"$IF\") OR (process == \"airportd\" AND (eventMessage CONTAINS \"DISASSOC\" OR eventMessage CONTAINS \"linkDown\"))" \
        > "$1/syslog-$(date -r "$2" +%H%M%S).txt" 2>&1
}

summary() {  # $1 run dir
    local ev="$1/events.log"
    echo "== $(basename "$1"): $(grep ' DROP #' "$ev" | grep -vc planned) drops, $(awk '/ BACK #/ && !/planned/{for(i=1;i<=NF;i++) if($i=="after") s+=$(i+1)} END{print s+0}' "$ev")s without working internet (planned auto-rejoins not counted) =="
    grep -E ' (DROP|BACK) #|GAP' "$ev" || true
}

# shellcheck disable=SC2012  # run-* names are our own timestamps, ls sorts them oldest first
latest() { ls -d "$BASE"/run-* 2>/dev/null | tail -1; }

alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }  # $1 pid file

run() {
    alive "$PIDFILE" && { echo "already running (pid $(cat "$PIDFILE"))"; exit 1; }
    local dir
    dir="$BASE/run-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$dir"; echo $$ > "$PIDFILE"
    EV="$dir/events.log"; CSV="$dir/samples.csv"
    caffeinate -i -w $$ &   # no idle sleep while this runs (closing the lid on battery still sleeps)
    trap 'note "stopped"; summary "$dir"; rm -f "$PIDFILE"; exit 0' INT TERM
    echo "time,state,wifi_link,ip,router,router_ok,internet_ms,web,lease_age_min,router_hw" > "$CSV"
    note "monitoring $IF every ${INTERVAL}s, evidence in $dir"
    local prev=OK n=0 down=0 seq='' pl='' last router='' now link ip r rok ims web hw st la
    last=$(date +%s)
    while :; do
        now=$(date +%s)
        [ $((now - last)) -gt 30 ] && note "GAP: no checks for $((now - last))s (Mac asleep?)"
        last=$now
        link=$(ifconfig "$IF" 2>/dev/null | awk '/status:/{print $2}')
        ip=$(ipconfig getifaddr "$IF" 2>/dev/null)
        r=$(ipconfig getoption "$IF" router 2>/dev/null); [ -n "$r" ] && router=$r  # remember it after the lease is gone
        hw=''; [ -n "$router" ] && hw=$(arp -n "$router" 2>/dev/null | awk '{print $4}')
        rok='' ims='' web='' st=OK
        if [ "$link" != active ]; then st=WIFI_DISCONNECTED
        elif [ -z "$ip" ] || [[ $ip == 169.254.* ]]; then st=NO_IP_ADDRESS
        else
            if router_ok "$router"; then rok=yes; else rok=no; fi
            ims=$(ms 1.1.1.1); [ -z "$ims" ] && ims=$(ms 8.8.8.8)   # second target so one lost packet is not a drop
            if [ -z "$ims" ]; then
                if [ $rok = yes ]; then st=INTERNET_DOWN; else st=ROUTER_UNREACHABLE; fi
            elif curl -s -m 3 http://captive.apple.com/hotspot-detect.html | grep -q Success; then web=ok
            else web=fail; st=WEB_FAILING
            fi
        fi
        la=$(lease_age_min)
        echo "$(date '+%F %T'),$st,$link,$ip,$router,$rok,$ims,$web,$la,$hw" >> "$CSV"
        if [ "$st" != "$prev" ]; then
            if [ "$prev" = OK ]; then
                n=$((n + 1)); down=$now; seq=$st; pl=''
                [ -f "$BASE/rejoin.stamp" ] && [ $((now - $(stat -f %m "$BASE/rejoin.stamp"))) -lt 30 ] && pl=" (planned auto-rejoin)"
                note "DROP #$n$pl: $st | lease age ${la:-?} min | router $router hw ${hw:-?}"
            elif [ "$st" = OK ]; then
                note "BACK #$n$pl after $((now - down))s | $seq > OK"
                evidence "$dir" "$down" &
            else
                seq="$seq > $st"; note "      #$n now $st | lease age ${la:-?} min | router hw ${hw:-?}"
            fi
            prev=$st
        fi
        sleep "$INTERVAL"
    done
}

fixloop() {  # a fresh join gets an address in seconds even where renewals fail, so rejoin before the lease runs out
    alive "$BASE/fix.pid" && { echo "already on (pid $(cat "$BASE/fix.pid"))"; exit 1; }
    EV="$BASE/fix.log"; echo $$ > "$BASE/fix.pid"
    caffeinate -i -w $$ &
    local la lt a miss=0 off=''
    trap '[ -n "$off" ] && networksetup -setairportpower "$IF" on; note "auto-rejoin off"; rm -f "$BASE/fix.pid"; exit 0' INT TERM
    note "auto-rejoin on: Wi-Fi off/on ${REJOIN_EARLY}s before a short (<=$((MAX_LEASE / 60)) min) lease runs out"
    while :; do
        la=$(lease_age_min); lt=$(ipconfig getoption "$IF" lease_time 2>/dev/null)
        if networksetup -getairportpower "$IF" | grep -q ': On'; then   # never switch on Wi-Fi the user turned off
            a=$(ipconfig getifaddr "$IF")
            if [ -z "$a" ] || [[ $a == 169.254.* ]]; then miss=$((miss + 1)); else miss=0; fi
            if { [ -n "$la" ] && [ -n "$lt" ] && [ "$lt" -le $MAX_LEASE ] && [ $((la * 60)) -ge $((lt - REJOIN_EARLY)) ]; } || [ $miss -ge 3 ]; then
                note "rejoining (address age ${la:-none} min, lease ${lt:-?}s)"
                touch "$BASE/rejoin.stamp"   # lets the monitor label the blip as planned
                off=1; networksetup -setairportpower "$IF" off; sleep 2; networksetup -setairportpower "$IF" on; off=''
                sleep 20; miss=0
            fi
        fi
        sleep 10
    done
}

report() {  # one line per lost lease or Wi-Fi drop found in macOS's own log
    echo "Wi-Fi/DHCP history for $IF, last ${1:-24h}, from macOS's own log"
    /usr/bin/log show --last "${1:-24h}" --style compact --predicate \
        "process == \"configd\" AND subsystem == \"com.apple.IPConfiguration\" AND eventMessage CONTAINS \"$IF\"" 2>/dev/null |
    awk -v IF="$IF" '
        function sec(t,  a) { split(t, a, ":"); return a[1] * 3600 + a[2] * 60 + a[3] }
        function dur(a, b,  d) { if (a == "" || b == "") return "?"; d = sec(b) - sec(a); if (d < 0) d += 86400; return int(d / 60) "m" sprintf("%02d", d % 60) "s" }  # ponytail: assumes < 24h apart
        function v(x) { return x == "" ? "-" : x }
        /^20[0-9][0-9]-/ {
            t = substr($2, 1, 8); if (lost == "") day = $1
            if ($0 ~ "dhcp_bound\\(" IF "\\)") {
                if (lost != "") {
                    n++
                    printf "%s  #%d  address %s | renewal unanswered %s | address lost %s | Wi-Fi off/on %s | back %s  => no address %s, lease age at loss %s%s\n", \
                        day, n, v(lease), v(renew), lost, v(drop), t, dur(lost, t), dur(lease, lost), why
                }
                lease = t; renew = lost = drop = why = ""
            }
            else if ($0 ~ "DHCP " IF ": RENEW$" && renew == "") renew = t
            else if ($0 ~ /server not responding/) lost = t
            else if ($0 ~ IF " link INACTIVE") { if (drop == "") drop = t; if (lost == "") { lost = t; why = "  (Wi-Fi went off while the address was still valid: not a lease failure)" } }
        }
        END { if (n == 0) print "no drops found"; else printf "%d drops\n", n }'
}

shortcut() {  # double-clickable Desktop app: shows whether the fix is on and turns it on or off
    local app="$HOME/Desktop/Wi-Fi Fix.app" me
    me="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    osacompile -o "$app" <<EOF || return 1
set s to "WIFI_MONITOR_DIR=" & quoted form of "$BASE" & " bash " & quoted form of "$me" & " "
if (do shell script s & "fix-status") is "on" then
    display dialog "Wi-Fi auto-rejoin is ON." buttons {"Cancel", "Turn off"} default button 2 with title "Wi-Fi Fix"
    display dialog (do shell script s & "fix-off") buttons {"OK"} default button 1 giving up after 5 with title "Wi-Fi Fix"
else
    display dialog "Wi-Fi auto-rejoin is OFF." & return & return & "When on, Wi-Fi switches off and on for a few seconds shortly before the network address runs out, instead of the internet dropping for minutes." buttons {"Cancel", "Turn on"} default button 2 with title "Wi-Fi Fix"
    display dialog (do shell script s & "fix-on") buttons {"OK"} default button 1 giving up after 5 with title "Wi-Fi Fix"
end if
EOF
    echo "created $app"
}

case "${1:-run}" in
    run) run ;;
    start) nohup bash "$0" run >/dev/null 2>&1 & sleep 3; cat "$(latest)/events.log" ;;
    status) summary "$(latest)" ;;
    stop) if kill "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then sleep 3; summary "$(latest)"; else echo "not running"; fi ;;
    report) report "$2" ;;
    fix-on) if alive "$BASE/fix.pid"; then echo "already on"; else nohup bash "$0" fixloop >/dev/null 2>&1 & sleep 2; tail -1 "$BASE/fix.log"; fi ;;
    fix-off) if kill "$(cat "$BASE/fix.pid" 2>/dev/null)" 2>/dev/null; then echo "auto-rejoin off"; else echo "not running"; fi ;;
    fix-status) if alive "$BASE/fix.pid"; then echo on; else echo off; fi ;;
    fixloop) fixloop ;;
    shortcut) shortcut ;;
    *) sed -n '/^# Usage:/,/^# Author:/p' "$0" | sed '$d' ;;
esac
