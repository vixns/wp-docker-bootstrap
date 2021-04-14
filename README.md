# Wordpress docker bootstrap

Setup a docker wordpress installation in minutes and get ready to work with Vixns Clusters. Instatallation scripts will automatically download latest wordpress release, create mysql user and database and generate configuration files. It includes a lemp stack (nginx + php-fpm + mariadb), a [mailhog](https://github.com/mailhog/MailHog) instance to manage outgoing emails, and a minio instance that will make your wordpress website "S3 ready". 

## Usage

	git clone https://github.com/vixns/wp-docker-bootstrap myproject
	cd myproject
	./setup.sh

This script will ask some configuration options
A few environment variables can be set to automate the process

	`WP_LANG` the wordpress installation language, `en` and `fr` values are currently supported.
	`DOCKER_REGISTRY` the docker private registry FQDN, eg `docker.vixns.net`
	`PROD_FQDN` the production FQDN, eg `www.mywordpress.com`
	`PREPROD_FQDN` the staging FQDN, eg `staging.mywordpress.com`
	`PREPROD_USER` the staging http basic auth user
	`PREPROD_PASSWD` the http basic auth password

## Link to a git repository

	git remote add origin [Your repository url]


The "develop" branch will deploy a "staging" environnement. 
The "master" branch will deploy the prodduction environnement.


## Create and switch to "develop" branch
	
	git checkout -b develop

now, you're ready to work

## Core update
	
	./wp core update
	./wp core update-db

## Plugins

#### Plugins update

	./wp plugin update --all

#### Search for a plugin

	./wp plugin search [some text]

##### Example

	./wp plugin search gravatar

#### Install and activate a plugin

	./wp plugin install [name] --activate

##### Example

	./wp plugin install disable-user-gravatar --activate


## Themes

### Themes update

	./wp theme update --all

### Search for a theme

	./wp theme search [some text]

#### Example

	./wp theme search material

### Install and activate a theme

	./wp theme install [name] --activate

#### Example

	./wp theme install material --activate

## Database operations

### Export

	./scripts/export-database.sh

This script produce the `export.sql.gz` file.

### Import

	./scripts/import-database.sh export.sql.gz

or

	cat dump.sql | ./scripts/import-database.sh


## S3 operations

### Setup a remote bucket

First ask to the operation team a new S3 bucket, you'll need

- An endpoint url
- A bucket name
- A key/secret pair

Then run the following command :

	./scripts/mc alias set [name] [endpoint]/[bucket] [key] [secret]

##### Example

	./scripts/mc alias set remote_alias https://os.vixns.net:9000/mybucket mykey supersecret

### Mirror a bucket

Mirroring a bucket may result to a lot of network transit, high disk usage and transfer fees when cloning an Amazon S3 bucket.

Mirror remote to local

	./script/mc mirror [alias]/[bucket]/[path] minio/wordpress/[path]

Mirror local to remote

	./script/mc mirror minio/wordpress/[path] [alias]/[bucket]/[path]

##### Example

Mirroring an entire remote bucket localy

	./scripts/mc mirror remote_alias/mybucket/ minio/wordpress/


Mirroring only a specific folder from remote to local

	./scripts/mc mirror remote_alias/mybucket/uploads/2021 minio/wordpress/uploads/2021

Mirroring the local bucket to remote

	./scripts/mc mirror minio/wordpress/ remote_alias/mybucket/


Mirroring only a specific folder from local to remote

	./scripts/mc mirror minio/wordpress/uploads/2021 remote_alias/mybucket/uploads/2021


## Daily Workflow on Vixns clusters

### Send my local development version to staging for the first time

	./scripts/export-database.sh

Send the `export.sql.gz` file to the operation team.

Ask the operation team for a new S3 bucket, then create an alias whith these informations 

	./scripts/mc alias set staging [endpoint]/[bucket] [key] [secret]

Mirror your local store to staging

	./scripts/mc mirror minio/wordpress/ staging/[bucket]/

Push your git branch

	git push

Open a support ticket, the operation team will add the required secrets in the vault store and supervise the first deploy.


### Send my local development updates to staging 

If you made only code changes, run `git push`

If you've added some content and want to OVERWRITE the staging database

	./scripts/export-database.sh

Send the `export.sql.gz` file to the operation team.

If you've added some uploads content and want to merge them on staging ( may OVERWRITE existing files )

	./scripts/mc mirror minio/wordpress/ staging/[bucket]/

### Deploy to production for the first time

Merge the `develop` branch to `master`  on gitlab/github/bitbucket/...

Open a support ticket, the operation team will take care of the whole process.

### Update production from staging

Merge the `develop` branch to `master`  on gitlab/github/bitbucket/...

Staging database or uploads changes will NOT be sent to production.

If you need a production update requiring data overwrite from staging, you have to open a support ticket.
In this ticket you have to explicitly ask for production overwrite, this is your responsability.
