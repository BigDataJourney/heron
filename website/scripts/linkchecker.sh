#!/bin/bash
echo "Running linkchecker..."

WGET_LOG=wget.log
PORT=15532

# kill all running Hugo servers and start serving website in the background
killall hugo 2>/dev/null || true

# start HTTP server
hugo serve --port=$PORT --ignoreCache 1>/dev/null 2>&1 &

# sleep 10 seconds to make sure Hugo gets into background
sleep 10

# use wget as linkchecker
# Note:
#   wget return code is 4 (network err) even though there is no broken link.
#   This means we should examine wget's log.
wget --spider -r -l 10 -e robots=off -o $WGET_LOG -p "http://localhost:${PORT}/heron"

# kill Hugo running in background
killall hugo 2>/dev/null || true

# remove intermediate directory generated by Hugo
rm -rf "localhost\:${WGET_LOG}"

# check if wget found no broken link
NO_BROKEN_MSG="Found no broken links"
grep -n "${NO_BROKEN_MSG}" wget.log 1>/dev/null 2>&1

# get grep's return code
GREP_STATUS=$?
EXIT_CODE=0

if [[ $GREP_STATUS != 0 ]]; then
  # examine wget.log
  BROKEN_MSG="^Found.*broken link"
  BROKEN_MSG_LINE=$(grep -n "${BROKEN_MSG}" ${WGET_LOG})
  LN=$(echo "${BROKEN_MSG_LINE}" | cut -f1 -d:)
  LINES=$(tail "+${LN}" "${WGET_LOG}")
  BAD_LINKS=""
  COUNT=0
  # only keep broken links with prefix ``localhost:15532``
  for LINE in $LINES; do
    if [[ $LINE == *"${PORT}"* ]]
    then
      COUNT=$((COUNT + 1))
      BAD_LINKS="$BAD_LINKS $LINE"
    fi
  done
  if [[ $COUNT == 0 ]]
  then
    echo $NO_BROKEN_MSG
  else
    LINKS=""
    # grammar police
    if [[ $COUNT == 1 ]]
    then
      LINKS="link"
    else
      LINKS="links"
    fi
    echo "Found $COUNT broken $LINKS:"
    for BAD_LINK in $BAD_LINKS; do
      echo "  $BAD_LINK"
    done
    EXIT_CODE=1
  fi
else
  echo $NO_BROKEN_MSG
  rm -f $WGET_LOG
fi

killall hugo 2>/dev/null || true
exit $EXIT_CODE
