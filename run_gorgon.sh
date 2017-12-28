#!/usr/bin/env bash

docker-compose exec originator /bin/bash -c 'cd spec/dummy && gorgon'
