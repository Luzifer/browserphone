#!/usr/local/bin/dumb-init /bin/bash
set -euxo pipefail

if [[ ! -f index.html.dist ]]; then
	mv index.html index.html.dist
fi

korvike -i index.html.dist -o index.html

exec python -m http.server 3000
