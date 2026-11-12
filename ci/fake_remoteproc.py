#!/usr/bin/env python3
"""A scripted stand-in for the remoteproc sysfs tree, to test handbook-rpu on any host.

Usage: fake_remoteproc.py <root> <initial state> <mode>
  mode ok     a write of 'start' makes the state 'running' after 0.3 s; 'stop' makes it 'offline'
  mode hang   a write of 'start' leaves the state 'offline' (the core never comes up)
It creates <root>/remoteproc0 with name, firmware and state files, and runs until it is killed.
"""
import os, sys, time
root, state, mode = sys.argv[1], sys.argv[2], sys.argv[3]
d = os.path.join(root, "remoteproc0"); os.makedirs(d, exist_ok=True)
for f, v in (("name", "ff9a0000.rf5ss:r5f_0"), ("firmware", ""), ("state", state)):
    open(os.path.join(d, f), "w").write(v + "\n")
print("ready", flush=True)
while True:
    time.sleep(0.05)
    s = open(os.path.join(d, "state")).read().strip()
    if s == "start":
        time.sleep(0.3)
        open(os.path.join(d, "state"), "w").write(("running" if mode == "ok" else "offline") + "\n")
    elif s == "stop":
        open(os.path.join(d, "state"), "w").write("offline\n")
