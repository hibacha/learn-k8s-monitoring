#!/bin/bash

host=http://node-app:8080/doWork

response=$(curl -s -I $host/ | head -n1)

if [[ "$response" != *"200"* ]]; then
  echo "Didn't get expected 200"
  echo "response: $response"
  exit 1
fi
