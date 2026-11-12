#!/bin/bash
# Simulated power cuts on ext4 (chapter 7). Needs root, loop devices, e2fsprogs, python3.
# A cut is a copy of the backing file taken while a writer runs. The copy holds every block the kernel had already
# submitted to the loop device and nothing that was still in the page cache. It models a perfect block device.
# It does not model flash translation layers, volatile device caches or write reordering inside a device.
# Usage: [TRIALS=15] [CUT_AFTER=seconds] run-powercut.sh. Output goes to out/powercut.txt, or to
# out/powercut-after-<CUT_AFTER>s.txt when CUT_AFTER is set. Without CUT_AFTER the cut comes 0.2 to 0.6 seconds after the start
# of the writer, which is before the kernel writes back dirty pages (30 seconds by default). CUT_AFTER=40 cuts after that age.
cd "$(dirname "$0")"; mkdir -p out; W=/tmp/pc${CUT_AFTER:+-late}; trials=${TRIALS:-15}
run_case() { # label mkfs-opts mount-opts
  local label=$1 mkfs=$2 mopt=$3 clean=0 replay=0 fsckbad=0 lost=0 plainshort=0 plainfound=0 plainwritten=0 tot_acked=0
  for t in $(seq 1 $trials); do
    rm -rf $W; mkdir -p $W/live $W/copy; truncate -s 256M $W/live.img
    mke2fs -q -F -t ext4 $mkfs $W/live.img
    mount -o loop,$mopt $W/live.img $W/live
    python3 writer.py $W/live $W/ack & wp=$!
    sleep ${CUT_AFTER:-0.$((2 + RANDOM % 5))}
    cp $W/ack $W/ack.cut                             # acks are logged after fsync returns, so every ack in this copy was durable before the cut below
    cp --sparse=always $W/live.img $W/cut.img        # the power cut
    pw=$(ls $W/live/plain | wc -l)                  # unsynced files that exist in the running file system when the copy ends
    kill -9 $wp 2>/dev/null; wait $wp 2>/dev/null; umount $W/live
    [ "$(dumpe2fs -h $W/cut.img 2>/dev/null | grep -c needs_recovery)" -ge 1 ] && replay=$((replay+1))
    mount -o loop $W/cut.img $W/copy
    read a ok bad pf pc ps < <(python3 verify.py $W/copy $W/ack.cut)
    umount $W/copy
    e2fsck -fn $W/cut.img >/dev/null 2>&1 || fsckbad=$((fsckbad+1))
    tot_acked=$((tot_acked+a)); lost=$((lost+bad)); plainshort=$((plainshort+ps)); plainfound=$((plainfound+pf)); plainwritten=$((plainwritten+pw))
  done
  printf "cut %-8s %-30s trials %2d  journal replay needed %2d  fsck errors after replay %2d  synced files acknowledged %5d lost or damaged %d  unsynced files written %5d found %5d incomplete %d\n" \
    "${CUT_AFTER:-0.2-0.6}s" "$label" $trials $replay $fsckbad $tot_acked $lost $plainwritten $plainfound $plainshort
}
{
  run_case "ext4 defaults (data=ordered)" "" "data=ordered"
  run_case "ext4 commit=1" "" "data=ordered,commit=1"
  run_case "ext4 data=writeback" "" "data=writeback"
} > out/powercut${CUT_AFTER:+-after-${CUT_AFTER}s}.txt 2>&1
rm -rf $W; cat out/powercut${CUT_AFTER:+-after-${CUT_AFTER}s}.txt
