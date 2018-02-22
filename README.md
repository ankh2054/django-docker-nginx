![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

### TO-DO

update settings.py with following:

	STATIC_URL = '/static/'
	STATIC_ROOT = os.path.join(BASE_DIR, 'static')


# DJANGO-DOCKER

django-docker sets up a container running django, gunicorn python, based on variables provided. It will automatically start gunicorn using the WSGI variable provided. 


### DJANGO-DOCKER Usage


Firstly you need to create the necessary folders on your docker host. The container will expose directories created below directly into the container to ensure our WWW, and LOG folders are persistent.
This ensures that even if your container is lost or deleted, you won't loose your MODX database or website files.

	$ mkdir -p /data/sites/www.test.co.uk/www
	$ mkdir -p /data/sites/www.test.co.uk/logs



To buld the docker modx image:

Download and extract files to modx/ directory. 

		$ cd django/
		$ docker build https://github.com/ankh2054/django-docker-nginx.git -t django-nginx 

To run it:

    $ docker run  --name docker.django --expose 80 \
	 -d -e 'VIRTUAL_HOST=www.test.co.uk' \
	 -e 'DJANGO_APP_NAME=test' \
	 -e 'PIP_PACKAGES=django==1.11 gunicorn dj-static django-anymail mysqlclient'
	 -e 'DB_NAME=django'
	 -e 'DB_USER=django'
	 -e 'DB_PASS=django'
	 -e 'ROOT_PWD=django'
	 -v /data/sites/www.test.co.uk/mysql:/var/lib/mysql \
	 -v /data/sites/www.test.co.uk:/DATA django


This will create a new DJANGO APP with the following values:

	$ Virtual Host: - www.test.co.uk
	$ Django App Name: test
	$ Pip install django==1.11 gunicorn django-anymail mysqlclient
	$ Mysql DB: django
	$ Mysql user to access django DB: django
	$ Mysql password for user: django
	$ Mysql root password: django
	


# NGINX-PROXY




nginx-proxy sets up a container running nginx and [docker-gen][1].  docker-gen generates reverse proxy configs for nginx and reloads nginx when containers are started and stopped.

See [Automated Nginx Reverse Proxy for Docker][2] for why you might want to use this.

### Nginx-proxy Usage

To run it:

    $ docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock:ro etopian/nginx-proxy




[1]: https://github.com/etopian/docker-gen
[2]: http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/

