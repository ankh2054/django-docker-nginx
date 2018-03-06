#!/bin/sh

# MYSQL SETUP 
#
# ###########


create_data_dir() {
  echo "Creating /var/lib/mysql"
  mkdir -p /var/lib/mysql
  chmod -R 0700 /var/lib/mysql
  chown -R mysql:mysql /var/lib/mysql
}

create_run_dir() {
  echo "Creating /run/mysqld"
  mkdir -p /run/mysqld
  chmod -R 0755 /run/mysqld
  chown -R mysql:root /run/mysqld
}

create_log_dir() {
  echo "Creating /var/log/mysql"
  mkdir -p /var/log/mysql
  chmod -R 0755 /var/log/mysql
  chown -R mysql:mysql /var/log/mysql
}

mysql_default_install() {
  if [ ! -d "/var/lib/mysql/mysql" ]; then
      echo "Creating the default database"
      /usr/bin/mysql_install_db --datadir=/var/lib/mysql

  else
      echo "MySQL database already initialiazed"
  fi
}

create_django_database() {

  if [ ! -d "/var/lib/mysql/${DB_NAME}" ]; then

     # start mysql server.
      echo "Starting Mysql server"
      /usr/bin/mysqld_safe >/dev/null 2>&1 &

     # wait for mysql server to start (max 30 seconds).
      timeout=30
      echo -n "Waiting for database server to accept connections"
      while ! /usr/bin/mysqladmin -u root status >/dev/null 2>&1
      do
        timeout=$(($timeout - 1))
        if [ $timeout -eq 0 ]; then
          echo -e "\nCould not connect to database server. Aborting..."
          exit 1
        fi
        echo -n "."
        sleep 1
      done
      echo
      
      # create database and assign user permissions.
      if [ -n "${DB_NAME}" -a -n "${DB_USER}" -a -n "${DB_PASS}" ]; then
         echo "Creating database \"${DB_NAME}\" and granting access to \"${DB_USER}\" database."
          mysql -uroot  -e  "CREATE DATABASE ${DB_NAME};"
          mysql -uroot  -e  "GRANT USAGE ON *.* TO ${DB_USER}@localhost IDENTIFIED BY '${DB_PASS}';"
          mysql -uroot  -e  "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_USER}@localhost;"

      else
        echo "How have not provided all the required ENV variabvles to configure the database"

      fi
  else 
      echo "Database \"${DB_NAME}\" already exists"

  fi
  
}

set_mysql_root_pw() {
    # Check if root password has already been set.
    r=`/usr/bin/mysqladmin -uroot  status`
    if [ ! $? -ne 0 ] ; then
      echo "Setting Mysql root password"
      /usr/bin/mysqladmin -u root password "${ROOT_PWD}"

      # shutdown mysql reeady for supervisor to start mysql.
      timeout=10
      echo "Shutting down Mysql ready for supervisor"
      /usr/bin/mysqladmin -u root --password=${ROOT_PWD} shutdown
      
      else 
       echo "Mysql root password already set"
    fi
    
}



#
# Creating supervisor file
###########################
create_supervisor_conf() {
  rm -rf /etc/supervisord.conf
  cat > /etc/supervisord.conf <<EOF
[unix_http_server]
file=/var/run/supervisor.sock   ; 
chmod=0700                       ; 

[supervisord]
logfile=/var/log/supervisord.log ; 
pidfile=/var/run/supervisord.pid ; 
childlogdir=/var/log/           ; 

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock ; 

[program:nginx]
command=/usr/sbin/nginx
autorestart=true
autostart=true

[program:mysqld]
command=mysqld_safe
autostart=true
autorestart=true

[program:gunicorn]
command=gunicorn ${DJANGO_APP_NAME}.wsgi:application --bind 0.0.0.0:8000 --workers 3
directory=/DATA/www/
autostart=true
autorestart=true
user=nginx

numprocs=1
EOF
}

# WWW & LOGS 
#
# ################

create_www_dir() {
  # Create LOG directoties for NGINX & PHP-FPM
  echo "Creating www directories"
  mkdir -p /DATA/www
  mkdir -p /DATA/logs

}

apply_www_permissions(){
  echo "Applying www permissions"
  chown -R nginx:nginx /DATA/www /DATA/logs

}


# PIP install 
#
##############

pip_install(){
  echo 'Creating temporary file with pip requirements in one line with spaces'
  cat > /DATA/www/temp.txt <<EOF
${PIP_PACKAGES}
EOF
  echo 'Using sed to turn white space into new lines'
  sed 's/\s\+/\n/g' /DATA/www/temp.txt > /DATA/www/requirements.txt && rm /DATA/www/temp.txt
  echo 'Pip install requirements.txt' 
  pip install --no-cache-dir -r /DATA/www/requirements.txt 
}


# DJANGO INSTALL  
#
# ################

django_install(){
  # Copy Django app files if file do not already exist.
  echo "Installing New Django app if not already installed"
  if [ ! -e /DATA/www/manage.py ] ; then

  # Creating django project. 
  echo "Creating your Django Project"
  /usr/bin/django-admin.py startproject ${DJANGO_APP_NAME} /DATA/www

  # Update settings.py
  echo "Updating Django settings.py with Mysql values"
  awk 'function pr(sp, k, v){    # prints key-value pair with indentation
         printf "%s\047%s\047: \047%s\047,\n",sp,k,v; 
     }
    BEGIN {
    db_user = ENVIRON["DB_USER"]
    db_pass = ENVIRON["DB_PASS"]
    db_name = ENVIRON["DB_NAME"]
    }
     /DATABASES/{ f=1 }/AUTH_PASSWORD_VALIDATORS/{ f=0 }
     /sqlite/{ sub(/sqlite[0-9]*/,"mysql",$0) }
     /NAME/ && f{ sp=substr($0,1,index($0,"\047")-1); 
             print sp$1" \047" db_name "\047,"; 
             pr(sp,"USER", db_user); pr(sp,"PASSWORD", db_pass); 
             pr(sp,"HOST","localhost"); pr(sp,"PORT",""); next 
    }1' /DATA/www/${DJANGO_APP_NAME}/settings.py > tmp.txt && mv tmp.txt /DATA/www/${DJANGO_APP_NAME}/settings.py

    # Update settings.py
    echo "Adding static root"
    sed -i -e '$a\STATIC_ROOT = os.path.join(BASE_DIR, "static")' /DATA/www/${DJANGO_APP_NAME}/settings.py

    # Create staticfiles
    echo "Running collectstatic"
    cd /DATA/www/ && python manage.py collectstatic


  else
    echo "Django already installed"

  fi

}


# Running all our scripts
create_data_dir
create_run_dir
create_log_dir
mysql_default_install
create_django_database
set_mysql_root_pw
create_www_dir
apply_www_permissions
pip_install
django_install
create_supervisor_conf




# Start Supervisor 
echo "Starting Supervisor"
/usr/bin/supervisord -n -c /etc/supervisord.conf
