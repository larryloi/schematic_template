#!/bin/bash

  HILN()
    {
      echo -e "\n\e[33m>>> ${1}\e[0m"
    }

HILN "Shutting down containers ...\n"
docker-compose down -v

HILN "Running containers.\n"; docker-compose ps; HILN "Docker volumes.\n"; docker volume ls
