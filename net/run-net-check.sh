#!/bin/bash
# Check the network configuration of chapter 7. Output goes to out/net_check.txt. Needs root, nft, ip, python3.
# NETWORKD=<path to systemd-networkd> turns on the key name check (default /usr/lib/systemd/systemd-networkd).
cd "$(dirname "$0")"; mkdir -p out
NETWORKD=${NETWORKD:-/usr/lib/systemd/systemd-networkd}
{
echo '# 1. Key names against the systemd-networkd binary'
if [ -x "$NETWORKD" ]; then
  bad=0
  for f in 10-eth0.network 10-vlan20.netdev 20-vlan20.network; do
    sec=""
    while IFS= read -r line; do
      case "$line" in \[*\]) sec=${line#[}; sec=${sec%]};; *=*) k=${line%%=*}
        if strings -a "$NETWORKD" | grep -qx "$sec.$k"; then :; else echo "UNKNOWN $f: [$sec] $k"; bad=$((bad+1)); fi;; esac
    done < "$f"
  done
  echo "keys checked in 3 files, unknown keys: $bad"
else echo "skipped: no systemd-networkd binary"; fi
echo
echo '# 2. Syntax of the ruleset'
echo '$ nft -c -f handbook-firewall.nft'; nft -c -f handbook-firewall.nft && echo "exit status 0"
sed 's/tcp dport 443 accept/tcp dport 443 acept/' handbook-firewall.nft > /tmp/broken.nft
echo '$ nft -c -f broken.nft   # one letter missing in "accept"'; nft -c -f /tmp/broken.nft 2>&1 | sed -n 1,2p | sed 's#/tmp/##'; echo "exit status ${PIPESTATUS[0]}"
echo
echo '# 3. Packets against the loaded ruleset (two peers, veth pairs, network namespaces)'
for n in dev pdata pmgmt; do ip netns del $n 2>/dev/null; ip netns add $n; done
ip link add eth0 netns dev type veth peer name p0 netns pdata
ip link add vlan20 netns dev type veth peer name p0 netns pmgmt
ip -n dev addr add 192.0.2.10/24 dev eth0;       ip -n pdata addr add 192.0.2.50/24 dev p0
ip -n dev addr add 198.51.100.10/24 dev vlan20;  ip -n pmgmt addr add 198.51.100.50/24 dev p0
for n in dev pdata pmgmt; do ip -n $n link set lo up; done
ip -n dev link set eth0 up; ip -n dev link set vlan20 up; ip -n pdata link set p0 up; ip -n pmgmt link set p0 up
ip -n pdata route add 198.51.100.0/24 via 192.0.2.10
ip netns exec dev nft -f handbook-firewall.nft
cat > /tmp/listen.py <<'PY'
import socket, sys, threading, time
def serve(p):
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("0.0.0.0", p)); s.listen(8)
    while True: s.accept()[0].close()
for p in (22, 443, 502, 8080): threading.Thread(target=serve, args=(p,), daemon=True).start()
time.sleep(20)
PY
ip netns exec dev python3 /tmp/listen.py & sleep 1
probe() { ip netns exec $1 python3 - "$2" "$3" <<'PY'
import socket, sys
s = socket.socket(); s.settimeout(1)
try: s.connect((sys.argv[1], int(sys.argv[2]))); print("open")
except socket.timeout: print("dropped")
except OSError as e: print("refused" if e.errno == 111 else "error")
PY
}
fail=0
expect() { # from-ns target port expected
  got=$(probe $1 $2 $3); res=PASS; [ "$got" = "$4" ] || { res=FAIL; fail=$((fail+1)); }
  printf "%s  %-6s -> %-14s port %-4s expect %-8s got %s\n" $res $1 $2 $3 $4 $got; }
expect pdata 192.0.2.10 22 dropped;      expect pdata 192.0.2.10 443 open
expect pdata 192.0.2.10 502 open;        expect pdata 192.0.2.10 8080 dropped
expect pmgmt 198.51.100.10 22 open;      expect pmgmt 198.51.100.10 443 open
expect pmgmt 198.51.100.10 502 dropped;  expect pmgmt 198.51.100.10 8080 dropped
expect pdata 198.51.100.10 22 dropped   # the management address, reached through the control interface
echo "failures: $fail"
n=0; for i in 1 2 3 4 5 6 7 8 9 10; do [ "$(probe pmgmt 198.51.100.10 22)" = open ] && n=$((n+1)); done
r=FAIL; [ $n -ge 3 ] && [ $n -le 6 ] && r=PASS
echo "$r  10 new SSH connections from the management peer in a row: $n accepted, $((10-n)) dropped (burst 5, refill 1 every 10 s)"
kill %1 2>/dev/null; for n in dev pdata pmgmt; do ip netns del $n; done
} > out/net_check.txt 2>&1
cat out/net_check.txt
