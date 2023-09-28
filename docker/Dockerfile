FROM schematic:0.2.0
LABEL maintainer="larry.loi@pm.me"

WORKDIR /app
ADD deploy/jobs /app/deploy/jobs
ADD RELEASE /app
ADD src/db/migrations /app/src/db/migrations
ADD src/stored_procedures /app/src/stored_procedures

# CMD $REL_PATH/start-archive.sh
ENTRYPOINT ["/bin/bash", "-c"]
# CMD ["rake", "db:migrate"]
# CMD ["sleep", "infinity"]

LABEL application=schematic_template
