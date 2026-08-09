#!/bin/bash
# run_tests.sh

passed=()
failed=()

for f in test/pif/positives/*.peml; do
    echo "Processing $f..."

    if pif "$f" ./parsed-json -f rs; then
        passed+=("$f")
    else
        failed+=("$f")
    fi
done

echo
echo "=============================="
echo "          SUMMARY"
echo "=============================="

echo
echo "Parsed successfully (${#passed[@]}):"
for f in "${passed[@]}"; do
    echo "  ✓ $f"
done

echo
echo "Failed (${#failed[@]}):"
for f in "${failed[@]}"; do
    echo "  ✗ $f"
done