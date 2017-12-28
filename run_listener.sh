#!/usr/bin/env bash

docker-compose exec listener /bin/bash -c 'cd spec/dummy && gorgon listen'
