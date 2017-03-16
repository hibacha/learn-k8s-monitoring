#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

publish_tag=$1

echo
echo "=== Starting artifact for component test."
echo

# Start our packaged container with a dummy config.
(set -x; docker run -d \
  --name node-app \
  -e TOKEN=yada \
  $publish_tag)

# Wait for container to startup.
# Looking for the server listening item.
waiting=true
wait_remaining=10
while [ "$waiting" == "true" ] && [ "$wait_remaining" -gt 0 ]; do
  sleep 2
  response=$(docker logs node-app)
  if [[ "$response" == *"listening on"* ]]; then
    waiting=false
  else
    echo "Waiting on container startup..."
  fi
  let "wait_remaining=$wait_remaining-2"
done

# Run our test script in a basic curl container.
docker run --link node-app:node-app \
--name node-app-tester \
-v $DIR:/var/test \
  buildpack-deps:curl /var/test/test.sh

exit_code=$?

if [ "$exit_code" != 0 ]; then
  echo
  echo "=== Component test failed."
  echo "=== Logs from node-app container"
  echo
  docker logs node-app
  echo
  echo "=== End container logs"
  echo
else
  echo
  echo "== Component test passed."
  echo
fi

docker rm -f node-app node-app-tester

exit $exit_code
