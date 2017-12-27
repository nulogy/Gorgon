#!/usr/bin/env bash

docker-compose exec listener /bin/bash -c 'cd tests/end_to_end && gorgon listen'
