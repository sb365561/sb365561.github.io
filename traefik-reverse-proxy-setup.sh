#!/bin/bash

###############
# Script to demo traefik as a reverse proxy
###############

# https://stackoverflow.com/a/7869065
warn () {
    echo "$0:" "$@" >&2
}
die () {
    rc=$1
    shift
    warn "$@"
    exit $rc
}


# Get the sudoing out of the way in the beginning
# docker needs sudo
a="$(sudo echo bla)"

# docker-proxy is the name of the docker process that runs our containers
ports_used=$(sudo netstat -anp |grep LISTEN | grep ':80 ' | grep -v docker-proxy)

# This doesn't work. It prints error even though ports_used is empty

# if [ -n "ports_used" ]; then die 1 "
# ERROR: Something is using the ports already.
#  $ports_used";
#  fi


mkdir myhello;
cd myhello;
dotnet new mvc;

dotnet publish --configuration=Release;


echo '
FROM microsoft/dotnet
WORKDIR /inetpub/wwwroot
COPY bin/Release/netcoreapp2.1/publish ./
EXPOSE 80
ENTRYPOINT ["dotnet", "myhello.dll"] ' > dockerfile;

sudo docker build -t myhello . ;


echo 'version: "3.1"
services:

    myhello:
        image: myhello
        labels:        
            - "traefik.backend=myhello-web"      

            # This will redirect /myhello to /myhello/
            # https://docs.traefik.io/user-guide/examples/
            # The very last example shows how to redirect from /myhello to /myhello/
            - "traefik.frontend.redirect.regex=^(.*)/myhello$$"
            - "traefik.frontend.redirect.replacement=$$1/myhello/"      
            - "traefik.frontend.rule=PathPrefix:/myhello;ReplacePathRegex: ^/myhello/(.*) /$$1"

            - "traefik.enable: True"
            - "traefik.port: 80" ' > myhello-compose.yml;


echo "MyHello..."
sudo docker-compose -f myhello-compose.yml up -d # --remove-orphans



echo 'version: "3.1"
services:
    frontend:
        image: traefik
        command: --api --docker --logLevel=DEBUG
        ports:
            - "80:80"
            - "443:443"

        # Expose the Traefik web UI on port 8080. We restrict this
        # to localhost so that we dont publicly expose the
        # dashboard.
            - "127.0.0.1:8080:8080"
        volumes:
            - "/var/run/docker.sock:/var/run/docker.sock"
        labels:
            traefik.enable: False ' > traefik-reverse-proxy-compose.yml;







echo "Traefik..."
sudo docker-compose -f traefik-reverse-proxy-compose.yml up -d # --remove-orphans




echo "


Now, if no errors, open a browser and visit 

http://localhost/myhello

Shut the containers down with

sudo docker-compose -f ./myhello/myhello-compose.yml down;
sudo docker-compose -f ./myhello/traefik-reverse-proxy-compose.yml down


";
