# Sanction Search

Sanction Search is based entirely on Ruby on Rails.

### Setup

The only things you need to get it running are a properly set up Rails environment (http://rvm.io should be able to get you started), and a cloned copy of the repository (Shawn should send you a code archive if you don't have it already).

Some minor items when you first run the server, if you're looking to properly test reports:
- You'll want to run `rake db:seed`, which populates the database with the data in `seeds.rb`. 
- You'll want to run every single `*RefreshJob` in 
- You'll need a copy of `SanctionSearchEmployees.csv` if you are creating clients/facilities through the Web UI. 
  *This requirement can technically be made moot by handling the error when creating a client or facility when the  file is not present.*

Note on installing `pg` gem on an ARM mac: 

```bash
brew install libpq
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
gem install pg -v '1.2.3' --source 'https://rubygems.org/' # (note: replace this with the right version, it should also come from the failed bundle install command)
```

### Connecting to the cloud server

**Make sure you `chmod 0600 SanctionSearch.pem` before connecting or deploying, to avoid SSH errors.**

If you want to poke around on the cloud server, very simply, you can run the "cloud_connect.sh" script from the project's root directory. Since the key file `SanctionSearch.pem` is included in the project's codebase, this is doable without any kind of special setup.

### Deployment

Deployment is done using Capistrano. If you have never used Capistrano before, definitely check out the documentation on these repos:

- https://github.com/capistrano/capistrano
- https://github.com/capistrano-plugins/capistrano-unicorn-nginx
- https://github.com/seuros/capistrano-sidekiq

Capistrano makes it simple to manage deployment and application lifecycle directly from your command line. From the same place as you ran the cloud_connect script, you can run the following commands:

- `cap production deploy`
- This is the command you run every time you make code changes, commit them, and push them up to the master branch of the repository. It effectively pulls from the repository on the remote, then repacks and restarts the rails app and the sidekiq processor. This doubles as a "hard reset" command in case something ever goes wrong and you just want to reload the server configuration completely.
- `cap production unicorn:restart`
- `cap production sidekiq:restart`
- `cap production nginx:reload`
- these are more granular 'reloading' commands for the main components of the server that you can use to reload an individual service more quickly without `ssh`ing.

*If you get an error deploying, try following the steps in this Stack Overflow answer:* 

https://stackoverflow.com/a/15940055

### Database backups

Database backups are made daily at 4:30 AM EST and stored in the `~/backups` directory on the cloud server. They are also mirrored to a S3 bucket on Shawn's AWS account where they are moved to Glacier storage after 7 days and expired after 30 days. They are `tgz` compressed and you can load them into the `sanction_search` database after running `sudo su postgres` if you ever need to.

### Gotchas

- Note that the sidekiq scheduler is a local redis instance on the web server, so you can't enqueue jobs from within jobs. This might need to be fixed in the future, but for now it's not a use case, so we ignore it.

### Local environment

To avoid having to regenerate DBs locally, they can be copied from the sidekiq server using this command.

scp -i "SanctionSearch.pem" ubuntu@ec2-18-216-4-52.us-east-2.compute.amazonaws.com:/home/ubuntu/sanction-search/shared/db/txoig.db .

Replicate for all db's, and move them to the db directory.
Still it's a good idea to check that the RefreshJobs work, to make sure all pages are accessible, since some of them are blocked for non-US IPs.

### Restore production's backup in dev.
Useful for testing complex stuff

> scp -i "SanctionSearch.pem" ubuntu@ec2-18-220-29-50.us-east-2.compute.amazonaws.com:backups/sanction_search/2022.07.01.23.59.03/sanction_search.tar .
> tar -xf sanction_search.tar
> cd sanction_search/databases/
> gzip -d PostgreSQL.sql.gz
> rails db:drop RAILS_ENV=development
> rails db:create RAILS_ENV=development
> psql -U sanction_search -p 5432 sanction_search < PostgreSQL.sql

 ### Sidekiq gotchas
 
 there are some cron jobs on the web server that replicate csv files to Sidekiq server. If more servers are added, or ip changes, these commands should be fixed in order to replicate the files to all servers, because some jobs depends on these files.

# Stuck reports
Report.where("created_at >= ? and progress is null and error is null and data is null", Date.parse("01-04-2023"))