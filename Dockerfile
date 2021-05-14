FROM vixns/php-nginx:7.4-debian-nonroot
ARG UID=33
WORKDIR /wordpress
USER root
RUN apt-get update \
&& apt-get install --no-install-recommends -y default-libmysqlclient-dev default-mysql-client less unzip git iputils-ping \
&& rm -rf /var/lib/apt/lists/* \
&& docker-php-ext-install mysqli pdo_mysql \
&& pecl install pcov \
&& echo "extension=pcov" > /usr/local/etc/php/conf.d/pcov.ini \
&& curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
&& curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
&& chmod 755 /usr/local/bin/wp /usr/local/bin/composer \
&& usermod -u ${UID:-33} www-data \
&& chown -R www-data:www-data /etc/service /var/log/nginx /var/lib/nginx /etc/nginx/conf.d
COPY config/php /usr/local/etc/php-fpm.d
COPY config/nginx/nginx.conf /etc/service/nginx/nginx.conf
COPY config/nginx/nginx-run.sh /etc/service/nginx/run
COPY proxysql-run.sh /etc/service/proxysql/run
COPY update.sh /update.sh
COPY --chown=www-data:www-data wordpress /wordpress
ENV HOME=/tmp
USER www-data
