#!/bin/bash

  HILN()
    {
      echo -e "\n\e[33m>>> ${1}\e[0m"
    }

#HILN "Creating network ...\n"
docker network create --driver bridge integration || true

#docker volume create --driver local --name opsta-db || true
  START_DB()
    {
      HILN "Starting up database ...\n"
      docker-compose up -d db

      docker-compose exec db /mssql-init/wait-for-it.sh db:1433 -t 60 -- /mssql-init/configure-db.sh

    }


  START_APP()
    {
      HILN "Starting up archive service ...\n"
      #docker-compose up -d app
      HILN "Running DB migration for source database ...\n"
      make src.sch.up

      HILN "Loading Sample data into source database ...\n"
      make src.data.load

      HILN "Running DB migration for destination database ...\n"
      make dst.sch.up

      make job.deploy
      HILN "Running containers.\n"; docker-compose ps; HILN "Docker volumes.\n"; docker volume ls
    }

  BUILD_IMAGE()
    {
      HILN "Removeing archiver image ...\n"
      make rmi
      HILN "Building archiver image ...\n"
      make build
    }

############
### MAIN ###
############

  #BUILD_IMAGE
  START_DB
  #START_APP
