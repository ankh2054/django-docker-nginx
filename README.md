![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

### TO-DO

update settings.py with following:

	STATIC_URL = '/static/'
	STATIC_ROOT = os.path.join(BASE_DIR, 'static')


# DJANGO-DOCKER

django-docker sets up a container running django, gunicorn python, based on variables provided. It will automatically start gunicorn using the WSGI variable provided. 

If using Letsencrypt to automate the creation of a SSL certificate, you need to follow the Nginx-proxy Usage - to enable SSL support guidelines at the bottom of this page.


### DJANGO-DOCKER Usage


Firstly you need to create the necessary folders on your docker host. The container will expose directories created below directly into the container to ensure our WWW, and LOG folders are persistent.
This ensures that even if your container is lost or deleted, you won't loose your MODX database or website files.

	$ mkdir -p /data/sites/www.test.co.uk/www
	$ mkdir -p /data/sites/www.test.co.uk/logs



### To buld the docker django image:

		$ cd django/
		$ docker build https://github.com/ankh2054/django-docker-nginx.git -t django-nginx 

### To run it with LETENCRYPT:

    $ docker run  --name docker.django --expose 80 \
	 -d -e 'VIRTUAL_HOST=www.test.co.uk' \
	 -e 'DJANGO_APP_NAME=test' \
	 -e "VIRTUAL_HOST=nginx.42strings.co.uk" \
 	 -e "LETSENCRYPT_HOST=nginx.42strings.co.uk" \
	 -e "LETSENCRYPT_EMAIL=charles@structa.co.uk" \
	 -e 'PIP_PACKAGES=django==1.11 gunicorn dj-static django-anymail mysqlclient'
	 -e 'DB_NAME=django'
	 -e 'DB_USER=django'
	 -e 'DB_PASS=django'
	 -e 'ROOT_PWD=django'
	 -v /data/sites/www.test.co.uk/mysql:/var/lib/mysql \
	 -v /data/sites/www.test.co.uk:/DATA django-nginx


This will create a new DJANGO APP with the following values:

	$ Virtual Host: - www.test.co.uk
	$ Django App Name: test
	$ Pip install django==1.11 gunicorn django-anymail mysqlclient
	$ Mysql DB: django
	$ Mysql user to access django DB: django
	$ Mysql password for user: django
	$ Mysql root password: django
	$ SSL certificate created for the hostname nginx.42strings.co.uk with email address charles@structa.co.uk.
	
	Note that your container can still be listening on port 80, since all external connections will hit your NGINX proxy 	     first, whcih will force users onto HTTPS. 
	


# NGINX-PROXY


nginx-proxy sets up a container running nginx and [docker-gen][1].  docker-gen generates reverse proxy configs for nginx and reloads nginx when containers are started and stopped.

See [Automated Nginx Reverse Proxy for Docker][2] for why you might want to use this.

### Nginx-proxy Usage - to enable SSL support

To use it with original [nginx-proxy](https://github.com/jwilder/nginx-proxy) container you must declare 3 writable volumes from the [nginx-proxy](https://github.com/jwilder/nginx-proxy) container:
* `/etc/nginx/certs` to create/renew Let's Encrypt certificates
* `/etc/nginx/vhost.d` to change the configuration of vhosts (needed by Let's Encrypt)
* `/usr/share/nginx/html` to write challenge files.

Example of use:

* First start nginx with the 3 volumes declared:
```bash
$ docker run -d -p 80:80 -p 443:443 \
    --name nginx-proxy \
    -v /path/to/certs:/etc/nginx/certs:ro \
    -v /etc/nginx/vhost.d \
    -v /usr/share/nginx/html \
    -v /var/run/docker.sock:/tmp/docker.sock:ro \
    --label com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy \
    jwilder/nginx-proxy
```
The "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy" label is needed so that the letsencrypt container knows which nginx proxy container to use.

* Second start this container:
```bash
$ docker run -d \
    -v /path/to/certs:/etc/nginx/certs:rw \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    --volumes-from nginx-proxy \
    jrcs/letsencrypt-nginx-proxy-companion
```

Then start any containers you want proxied with a env var `VIRTUAL_HOST=subdomain.youdomain.com`

    $ docker run -e "VIRTUAL_HOST=foo.bar.com" ..




[1]: https://github.com/etopian/docker-gen
[2]: http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/

