#!/usr/bin/env bash

docker-compose exec originator /bin/bash -c 'cd tests/end_to_end && gorgon'
