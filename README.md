# docker_toolkit
Helper tools for work with docker and consul

[![Build Status](https://travis-ci.com/RnD-Soft/docker_toolkit.svg?branch=master)](https://travis-ci.com/RnD-Soft/docker_toolkit) [![Gem Version](https://badge.fury.io/rb/docker_toolkit.svg)](https://badge.fury.io/rb/docker_toolkit)

## Scripts

Some useful scripts to run inside or outside container

### waiter.rb

waiter.rb allows to wait many conditions:

* tcp port opening
* PostgreSQL database creation
* PostgreSQL table creation
* file creation
* healthy Consul service 

```
Usage: waiter.rb [options] -- exec
        --tcp host:port              Wait for tcp accepts on host:port
        --db dbname                  Wait for PG database exists. Using --tcp to conenct PG
        --tb tablename               Wait for PG table exists. Using --tcp to conenct PG
    -f, --file filename              Wait for file exists.
        --consul-addr addr=http://localhost:8500
                                     HTTP addres to connect to consul
        --consul                     Wait for local consul agent to be ready
        --consul-service service     Wait for service appear in consul
        --consul-service-count count Wait for this count services appear in consul
        --consul-tag tag             User tag to filter services in consul
        --user user                  username
        --pass pass                  password
    -t, --timeout secs=15            Total timeout
    -i, --interval secs=2            Interval between attempts
    -q, --quiet                      Do not output any status messages
```


### consul.rb

Helper to use Consul in 12Factor application. Inspired by https://github.com/hashicorp/envconsul:

* export Consul key/value as environment variables
* references in Consul key/value store
* read config file and store values in Consul
* read files and store it in Consul key/value  store

```
Usage: consul.rb [options] -- exec
        --consul url                 Set up a custom Consul URL
        --token token                Connect into consul with custom access token (ACL)
        --init [service]             Initialize Consul services from config
        --config file                Read service configulation from file
        --upload                     Upload files to variables
        --show [service]             Show service configulation from Consul
        --override                   override existed keys
    -d, --dereference                dereference consul values in form of "consul://key/subkey"
        --env prefix                 export KV values from prefix as env varaibles
        --export                     add export to --env output
        --pristine                   not include the parent processes' environment when exec child process
        --put path:value             put value to path
        --get path                   get value from
```

Example config.yml:
```yaml
.dbconfig: &dbconfig
  DATABASE_HOST:
    value: db
  DATABASE_NAME:
    value: dbname

srv1: &srv1
  <<: [*dbconfig]
  LOG_LEVEL:
    value: debug
  CA_CERT:
    file: /tmp/ca/cacert.pem
  CLIENT_CERT:
    value: consul://services/ca/private/cert.pem
  CLIENT_KEY:
    value: consul://services/ca/private/key.pem

srv2:
  <<: *srv1
  CA_CERT:
    value: consul://services/env/srv1/ca_cert
```

### merger.rb

Merge docker-compose file of any version. Allow inheritance and extending services.
```bash
COMPOSE_FILE=file1.yml:file2.yml merger.rb > /tmp/result.yml
```
