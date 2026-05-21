#!/bin/bash

# Validates the three traffic scenarios of the Serverless AI-SEO Pipeline against
# the Akamai staging edge. Requires access to cdi.connected-cloud.io.
# Usage: ./validate-edge-seo.sh [target-url]
# If no URL is provided, defaults to the AT&T demo target.

# Accept a universal URL as the first argument, or default to AT&T if left blank
DEMO_URL=${1:-"https://www.akamai.com"}
# Normalize: add https:// if the caller omitted the scheme (e.g. "sportsbasement.com").
[[ "$DEMO_URL" != http://* && "$DEMO_URL" != https://* ]] && DEMO_URL="https://$DEMO_URL"

HOST_HEADER="cdi.connected-cloud.io"
STAGING_EDGE="cdi.connected-cloud.io.edgesuite-staging.net" 
TEST_PATH="/ai-seo-test" 

TARGET_URL="https://$STAGING_EDGE$TEST_PATH"
TIME_FORMAT="\nX-Response-Time: %{time_total} seconds\n"
FILTER='HTTP/|content-type|x-cache|x-wasm-execution|x-response-time'

echo "====================================================="
echo "TARGET: $DEMO_URL"
echo "====================================================="

echo ""
echo "====================================================="
echo "TEST A: Standard Human Browser Request"
echo "► STATUS: No X-Verified-Bot tag detected. Forwarding to Origin..."
echo "====================================================="
# -k disables SSL verification; required for staging edge certificates.
curl -k -i -s -G --data-urlencode "url=$DEMO_URL" -w "$TIME_FORMAT" -H "Host: $HOST_HEADER" "$TARGET_URL" | grep -Ei "$FILTER"

echo ""
echo "====================================================="
echo "TEST B: AI Bot Request (Compute Handoff)"
echo "► STATUS: X-Verified-Bot tag found. Intercepting and engaging Wasm Functions..."
echo "====================================================="
curl -k -i -s -G --data-urlencode "url=$DEMO_URL" -w "$TIME_FORMAT" -H "Host: $HOST_HEADER" -H "X-Verified-Bot: true" -H "Pragma: akamai-x-cache-on" "$TARGET_URL" | grep -Ei "$FILTER"

# Brief pause to allow the edge cache to propagate before the cache-hit test.
sleep 1

echo ""
echo "====================================================="
echo "TEST C: AI Bot Request (The Automated Payoff)"
echo "► STATUS: X-Verified-Bot tag detected. Checking Global Edge Cache..."
echo "====================================================="
curl -k -i -s -G --data-urlencode "url=$DEMO_URL" -w "$TIME_FORMAT" -H "Host: $HOST_HEADER" -H "X-Verified-Bot: true" -H "Pragma: akamai-x-cache-on" "$TARGET_URL" | grep -Ei "$FILTER"