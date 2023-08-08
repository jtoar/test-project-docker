#!/bin/sh

echo "Starting web server with api host: '$API_HOST'"
node_modules/.bin/rw-web-server --apiHost=$API_HOST
