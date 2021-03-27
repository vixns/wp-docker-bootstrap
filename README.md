# Wordpress docker bootstrap

## Usage

	git clone https://github.com/vixns/wp-docker-bootstrap myproject
	cd myproject
	./bootstrap.sh

This script will ask some configuration configuration
A few environment variables can be set to automate the process

	`WP_LANG` the wordpress installation language, `en` and `fr` values are currently supported.
	`DOCKER_REGISTRY` the docker private registry FQDN, eg `docker.vixns.net`
	`PROD_FQDN` the production FQDN, eg `www.mywordpress.com`
	`PREPROD_FQDN` the staging FQDN, eg `staging.mywordpress.com`
	`PREPROD_USER` the staging http basic auth user
	`PREPROD_PASSWD` the http basic auth password

## Link to a git repository

	git remote add origin [Your repository url]


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

