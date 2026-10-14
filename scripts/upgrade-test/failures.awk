# Classifies the failed requests of the load (load.sh) by phase of scripts/upgrade-test.sh. Reads the log of the load,
# and prints "<phase> <tolerated|failed> <FAIL line>" for each of its FAIL lines
# (FAIL <kind> #<n> <start> <end> <time> <code> <detail>, start and end in epoch seconds).
#
# Variables, in epoch seconds of the load pod, empty when the phase did not run:
#   upgraded    end of the upgrade
#   drained     end of the node drain
#   killed      force deletion of a backend pod
#   window      seconds after the deletion within which the requests must succeed again (default: 10)
#   disruption  non-empty when the upgrade has a documented outage (scripts/upgrade-test/disruptive.txt)
#
# Phases, by start of the request:
#   upgrade     before the end of the upgrade (failed, tolerated with a documented outage)
#   drain       before the end of the drain (failed)
#   loss        in flight at the deletion, or started within the window after it (tolerated)
#   steady      between the drain and the deletion (failed)
#   recovered   after the window (failed)

$1 == "FAIL" {
    start = $4 + 0
    end = $5 + 0
    if (window == "") window = 10
    if (killed != "" && ((start < killed && end >= killed) || (start >= killed && start < killed + window))) {
        phase = "loss"
    } else if (upgraded == "" || start < upgraded) {
        phase = "upgrade"
    } else if (drained == "" || start < drained) {
        phase = "drain"
    } else if (killed == "" || start < killed) {
        phase = "steady"
    } else {
        phase = "recovered"
    }
    verdict = (phase == "loss" || (phase == "upgrade" && disruption != "")) ? "tolerated" : "failed"
    print phase, verdict, $0
}
