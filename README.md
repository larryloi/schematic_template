# schematic_template
schematic_template - A template for building schema migration repo base on schematic docker image

- [schematic\_template](#schematic_template)
  - [Before Your Development](#before-your-development)
  - [Prepare schematic base image](#prepare-schematic-base-image)
  - [Prepare your new repo](#prepare-your-new-repo)
      - [Browse from VS code](#browse-from-vs-code)
      - [Update/Build your image for development](#updatebuild-your-image-for-development)
  - [Development Start](#development-start)
    - [Prepare your schema migration scripts](#prepare-your-schema-migration-scripts)
      - [Generate migration script template](#generate-migration-script-template)
      - [Create your own script](#create-your-own-script)
    - [Create your stored procedure](#create-your-stored-procedure)
    - [Create you agent jobs](#create-you-agent-jobs)
  - [Post steps](#post-steps)
    - [Build your docker image](#build-your-docker-image)
    - [Commit you code](#commit-you-code)
  - [Addition info](#addition-info)

## Before Your Development
It is recommanded to set the default user to root for you WSL to prevent user permission issue while writing files within container. RUN the below in Windows ``CMD.exe``.
```cmd
ubuntu2204.exe config --default-user root
```

## Prepare schematic base image
```shell
cd <Your-Prefer-Path>
git clone https://github.com/larryloi/schematic
cd schematic/docker
make build
```
Or Use **VScode**,
1. Open Remote Explorer and connect Remote Host
2. Clone a remote Git Repository
3. and run ``make build`` as above

The docker image schematic should be built after finished above commands
type ``docker images`` shows you the docker images you've just built.
```shell
docker images
REPOSITORY    TAG         IMAGE ID       CREATED         SIZE
schematic     0.2.0       d47ae698c7fc   17 hours ago    406MB
```


## Prepare your new repo
**Method 1.** Clone from git repo
  go to New --> Import repo from existing repo URL

**Method 2.** Create New repo, and copy all the file from schematic_template
   
Checkout the schematic_template and New created ETL repo
```shell
cd <Your-Prefer-Path>
git clone https://github.com/larryloi/schematic_template
git clone <Your-Repo_URL>
cd schematic_template 
cp -rp * ../<Your-New-Repo-Name>
cp .env ../<Your-New-Repo-Name>
```
Current schematic_template repo URL is
https://github.com/larryloi/schematic_template


#### Browse from VS code
After clone you repo, you may explore/edit it's file by VScode
  1. **login remotely** to you ubuntu
  2. choose **Open Folder** and select your repo folder root


#### Update/Build your image for development
Update ``IMAGE/TAG`` in RELEASE file

```shell
cd docker
make build
```
> **_NOTE:_** If make command is not avaliable, please follow bellow to install

```shell
sudo apt update
sudo apt install make
```



## Development Start
First of all
Start up you personal docker environment for your development
execute the below command to start it up
```shell
cd docker
make all.up
```
Then 2 containers will be started, 1 is a SQL Server, another is your application 
```shell
         Name                       Command               State                    Ports
----------------------------------------------------------------------------------------------------------
db-sqlserver             /opt/mssql/bin/permissions ...   Up      0.0.0.0:1433->1433/tcp,:::1433->1433/tcp
schematic_template_app   /bin/bash                        Up
```


First of all, login to your new app by below command
```shell
cd docker
make bash
```

### Prepare your schema migration scripts
#### Generate migration script template
First of all, we have to generate migration script template,
Inside the container, Execute the below command, a sample migration script template will be generated under the path
``src/db/migrations/dst/``
file name has datetime prefix and sample.rb suffix like ``20230928024121_sample.rb``
```shell
make dst.sch.gen
```
You should rename the script as you want; 
For example, as below. make you file name meaningful
```
  20230928024121_create_table_emp.rb
  20230928024121_emp_add_index_name_dept_id.rb
  20230928024121_emp_add_column_age.rb
  20230928024121_emp_rename_column_remark_to_detail.rb
```

For your testing purpose, you may need to create some source table for test.
To generate the source template, type below command
```shell
make src.sch.gen
```
sample migration script generated under the path ``src/db/migrations/src``

#### Create your own script
Migration script is ruby Sequel implementation, and below is a sample that create a ``job_logs`` table with a composite index under particular db schema.
```ruby
Sequel.migration do
  up do
    create_table(dbschema(:job_logs)) do
      primary_key :id, type: 'INT', auto_increment: true
      String :name, size: 85, null: false
      String :type, size: 85, null: false
      String :message, size: 1024, null: false
      Datetime :started_at, null: false
      Datetime :ended_at, null: true
      Integer :duration, null: true

      index [:started_at, :name ]
    end
  end
  down do
    drop_table(dbschema(:job_logs))
  end
end
```

For more syntax and funtion, visit the below link
https://github.com/jeremyevans/sequel/blob/master/doc/schema_modification.rdoc

To execute the migration scripts, run the below command. This command will run all the migration script to latest.
```shell
make dst.sch.up
```

If you want to run migration script until a particular version, say 20171013065203, type the below in container
```shell
export DB_VERSION=20171013065203   
make dst.sch.to
```

the below command is rollback all the migration script to the beginning.
```shell 
make dst.sch.down
```

To run the migration script for source, run the below
```shell
make src.sch.up

export DB_VERSION=20171013065203  
make src.sch.to

make src.sch.down
```

### Create your stored procedure
Under the path ``src/stored_procedures``, You may put your own stored procedure there which is SQL format like below sample.

It is recommended to put the ``IF EXISTS BEGIN DROP PROCEDURE`` statement at the beginning. That is to make sure modify the existing stored procedures everytime.
```sql
IF EXISTS (SELECT * FROM sys.objects o JOIN sys.schemas s ON o.schema_id = s.schema_id WHERE type = 'P' AND o.name = 'sp_InsertRandomLog' AND s.name = 'DestSchema')
BEGIN
    DROP PROCEDURE [DestSchema].[sp_InsertRandomLog]
END
GO

CREATE PROCEDURE [DestSchema].[sp_InsertRandomLog]
AS
BEGIN
    DECLARE @name varchar(85)
    DECLARE @type varchar(85)
    DECLARE @message varchar(1024)
    DECLARE @started_at datetime
    DECLARE @ended_at datetime
    DECLARE @duration int

    -- Generate random values for each field
    SET @name = 'Job' + CAST(NEWID() AS varchar(36))
    SET @type = 'Type' + CAST(NEWID() AS varchar(36))
    SET @message = 'Message' + CAST(NEWID() AS varchar(36))
    SET @started_at = DATEADD(second, (ABS(CHECKSUM(NEWID())) % 86400), CAST(CAST(GETDATE() as date) as datetime))
    SET @ended_at = DATEADD(second, (ABS(CHECKSUM(NEWID())) % 86400), @started_at)
    SET @duration = DATEDIFF(second, @started_at, @ended_at)

    -- Insert the random log into the table
    INSERT INTO [DestSchema].[job_logs] ([name], [type], [message], [started_at], [ended_at], [duration])
    VALUES (@name, @type, @message, @started_at, @ended_at, @duration)
END
GO
```
After create the stored procedure; run below to deploy
```shell
make dst.sp.deploy
```

### Create you agent jobs
To create Agent jobs, we need to create folder and files under ``deploy/jobs``
Folder name represent job name, For example, the below directory ``InsertRandomLog`` is the job name.
``jobs`` folder and 2 file ``general.env`` and ``general.yml`` are always there for all default values.

We create new job folder, job.env and job.yml for new job.

```
├── deploy
│   └── jobs
│       ├── general.env
│       ├── general.yml
│       └── InsertRandomLog
│           ├── job.env
│           └── job.yml
```


Here is a sample for job.yaml
```yaml
---
  description: InsertRandomLog
  category_name: _Data_Maintenance
  owner_login_name: schematic
  schedule_name: Test_job_schedule02
  schedule_enabled: <%= ENV['INSERTRANDOMLOG_SCHEDULE_ENABLED'] || ENV['JOB_SCHEDULE_ENABLED'] || "true" %>
  schedule_freq_type: 4 <%= ENV['INSERTRANDOMLOG_SCHEDULE_FREQ_TYPE'] || ENV['JOB_SCHEDULE_FREQ_TYPE'] || "4" %>                               # 1: Once, 4: Daily, 8: Weekly, 16: Monthly, 32: Monthly, relative to @freq_interval., 64: Run when the SQL Server Agent service starts, 128: Run when the computer is idle.
  schedule_freq_interval: <%= ENV['INSERTRANDOMLOG_SCHEDULE_FREQ_INTERVAL'] || ENV['JOB_SCHEDULE_FREQ_INTERVAL'] || "1" %>                         # check https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-jobschedule-transact-sql?view=sql-server-ver16
  schedule_freq_subday_type: <%= ENV['INSERTRANDOMLOG_SCHEDULE_FREQ_SUBDAY_TYPE'] || ENV['JOB_SCHEDULE_FREQ_SUBDAY_TYPE'] || "8" %>
  schedule_freq_subday_interval: <%= ENV['INSERTRANDOMLOG_SCHEDULE_FREQ_SUBDAY_INTERVAL'] || ENV['JOB_SCHEDULE_FREQ_SUBDAY_INTERVAL'] || "1" %>
  schedule_freq_relative_interval: <%= ENV['INSERTRANDOMLOG_SCHEDULE_FREQ_RELATIVE_INTERVAL'] || ENV['JOB_SCHEDULE_FREQ_RELATIVE_INTERVAL'] || "0" %>
  schedule_freq_recurrence_factor: <%= ENV['INSERTRANDOMLOG_SCHEDULE_FREQ_RECURRENCE_FACTOR'] || ENV['JOB_SCHEDULE_FREQ_RECURRENCE_FACTOR'] || "0" %>
  schedule_active_start_date: <%= ENV['INSERTRANDOMLOG_SCHEDULE_ACTIVE_START_DATE'] || ENV['JOB_SCHEDULE_ACTIVE_START_DATE'] || "20181010" %>
  schedule_active_end_date: <%= ENV['INSERTRANDOMLOG_SCHEDULE_ACTIVE_END_DATE'] || ENV['JOB_SCHEDULE_ACTIVE_END_DATE'] || "99991231" %>
  schedule_active_start_time: <%= ENV['INSERTRANDOMLOG_SCHEDULE_ACTIVE_START_TIME'] || ENV['JOB_SCHEDULE_ACTIVE_START_TIME'] || "600" %>
  schedule_active_end_time: <%=  ENV['INSERTRANDOMLOG_SCHEDULE_ACTIVE_END_TIME'] || ENV['JOB_SCHEDULE_ACTIVE_END_TIME'] || "235959" %>
  step_general:
    cmdexec_success_code: 0
    retry_attempts: 0
    retry_interval: 0
    os_run_priority: 0
  job_steps:
    - id: 1
      name: Executing sp_user_operation_logs
      on_success_action: 1                      # 1: Quit with success, 2: Quit with failure, 3: Go to next step, 4: Go to step @on_success_step_id
      on_fail_action: 2                         # 1: Quit with success, 2: Quit with failure, 3: Go to next step, 4: Go to step @on_fail_step_id
      os_run_priority: 0
      subsystem: TSQL
      command: |
        EXEC [DestSchema].[sp_InsertRandomLog]
        GO;
        SELECT GETDATE();
        GO;
```


Here is a sample for job.env
```shell
INSERTRANDOMLOG_ENABLED=false
INSERTRANDOMLOG_NOTIFY_LEVEL_EMAIL=false
INSERTRANDOMLOG_NOTIFY_LEVEL_NETSEND=false
INSERTRANDOMLOG_NOTIFY_LEVEL_PAGE=false
INSERTRANDOMLOG_DELETE_LEVEL=false
INSERTRANDOMLOG_OWNER_LOGIN_NAME=schematic
INSERTRANDOMLOG_SCHEDULE_ENABLED=true
INSERTRANDOMLOG_SCHEDULE_FREQ_TYPE=4
INSERTRANDOMLOG_SCHEDULE_FREQ_INTERVAL=1
INSERTRANDOMLOG_SCHEDULE_FREQ_SUBDAY_TYPE=8
INSERTRANDOMLOG_SCHEDULE_FREQ_SUBDAY_INTERVAL=1
INSERTRANDOMLOG_SCHEDULE_FREQ_RELATIVE_INTERVAL=0
INSERTRANDOMLOG_SCHEDULE_FREQ_RECURRENCE_FACTOR=0
INSERTRANDOMLOG_SCHEDULE_ACTIVE_START_DATE=20181010
INSERTRANDOMLOG_SCHEDULE_ACTIVE_END_DATE=99991231
INSERTRANDOMLOG_SCHEDULE_ACTIVE_START_TIME=131300
INSERTRANDOMLOG_SCHEDULE_ACTIVE_END_TIME=235959
```

**Note.**  ``You may rename the variable name in the job.env and job.yml; but they should be match``

After created those job configuration, 
If we have new jobs environment variables. The container need to be restart to get the new create environment variables, type ``exit`` to exit the container and type below to restart it.

```shell
make app.down
make app.up
```
After that login to container again
```shell
make bash
```

execute the below to command to deploy jobs

``` shell
make dst.job.deploy
```

## Post steps
### Build your docker image 
Finally, confirm you new version by editing ``RELEASE`` file.
Build you image and test agin.

### Commit you code
Remember to commit your code to ``GitOps``

In VScode, 
- click ``Source Control``
- click ``+`` sign to Stage Change
- type you Message and click ``Commit`` then ``Push`` you change

---


## Addition info
- **Makefile**
    help command below show all available options
    ```shell
    make help
    help:
    concat_env_files:
    clean:
    build:
    run: concat_env_files
    bash: concat_env_files
    rmi:
    all.up:
    all.down:
    app.up:
    app.down:
    ```
- **docker-compose.yml**
    For different version of SQL Server tests. We have serval docker-compose.yml file for different version of SQL Server. create different symblic link to use different docker-compose.yml file, just do the below
    ```shell
    rm docker-compose.yml
    ln -s docker-compose-sqlserver-2022.yml docker-compose.yml
    ```
    It will create symblic link to the docker-compose.yml file for sql server 2022. 