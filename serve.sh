#!/bin/bash

set -e

rm -rf makelove-build
makelove lovejs
unzip -o "makelove-build/lovejs/changing-sides-chosen-1-lovejs" -d makelove-build/html/
echo "http://localhost:8000/makelove-build/html/changing-sides-chosen-1/"
python3 -m http.server