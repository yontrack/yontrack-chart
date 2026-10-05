#!/bin/bash
set -e

echo "Checking Docker images referenced in the Helm chart..."

# Extract images from Helm template
IMAGES=$(helm template charts/yontrack | grep "image:" | sed 's/.*image: //;s/"//g;s/^ //g' | sort | uniq)

FAILED=0

for IMAGE in $IMAGES; do
    echo -n "Checking $IMAGE... "
    if docker manifest inspect "$IMAGE" > /dev/null 2>&1; then
        echo -n "OK (reachable)"
        
        # Version checks
        TAG=${IMAGE##*:}
        
        if [[ "$IMAGE" =~ postgres ]]; then
            if [[ "$TAG" =~ ^17 ]]; then
                echo -n ", version 17 OK"
            else
                echo -n ", version $TAG NOT 17"
                FAILED=1
            fi
        fi
        
        echo ""
    else
        echo "FAILED (unreachable)"
        FAILED=1
    fi
done

if [ $FAILED -eq 1 ]; then
    echo "Some images are missing or unreachable."
    exit 1
else
    echo "All images are reachable."
    exit 0
fi
