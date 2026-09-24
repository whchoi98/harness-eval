# shellcheck shell=bash
# lib/grade.sh — the single definition of the harness-eval grade thresholds.
# Sourced (not executed) by scoring.sh (Quick/Standard) and aggregate.sh (Full), so
# every mode maps the same overall score to the same grade.
#
# score_to_grade <score>
#   Prints the grade for a 0-10 overall score, as emitted by the scoring scripts
#   (printf "%.1f"): A+ >= 9.5, A >= 9.0, A- >= 8.5, B+ >= 8.0, B >= 7.0, C >= 6.0,
#   else F. There is no D grade.
#   The score is passed to awk as data (awk -v), never interpolated into the program.

score_to_grade() {
  awk -v s="$1" 'BEGIN {
    if (s >= 9.5) print "A+"
    else if (s >= 9.0) print "A"
    else if (s >= 8.5) print "A-"
    else if (s >= 8.0) print "B+"
    else if (s >= 7.0) print "B"
    else if (s >= 6.0) print "C"
    else print "F"
  }'
}
