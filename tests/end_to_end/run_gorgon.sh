#!/usr/bin/env bash

set -e

export GORGON_PATH=/Users/arturopie/src/Gorgon

gorgon | sed 's/ at .*/ at hostname/g' | sed 's/\/Users\/[^\/]*/Users\/username/g' | sed 's/\/private\/var\/folders\/.*\/spec/temp_dir\/spec/g'
