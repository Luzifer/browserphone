#!/usr/local/bin/dumb-init /bin/bash
set -euxo pipefail

ln dist/app.js app.js
korvike -i dist/index.html -o index.html

exec python -m http.server 3000
