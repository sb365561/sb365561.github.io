# Setting up [Traefik2](https://traefik.io/) as a reverse-proxy with dotnet



Related:
* [Setting up Traefik as a Reverse Proxy for ASP.NET Applications](https://blog.codeship.com/setting-up-traefik-as-a-reverse-proxy-for-asp-net-applications/)
* [Ultimate Docker Home Server with Traefik 2, LE, and OAuth / Authelia [2020]](https://www.smarthomebeginner.com/traefik-2-docker-tutorial/)
* [Traefik 2.0 & Docker 101](https://containo.us/blog/traefik-2-0-docker-101-fc2893944b9d/)
* [Traefik 'PathPrefix' is not working as expected for underlying requests](https://stackoverflow.com/questions/61946945/traefik-pathprefix-is-not-working-as-expected-for-underlying-requests)

* [Dealing with Application Base URLs and Razor link generation while hosting ASP.NET web apps behind Reverse Proxies](https://www.hanselman.com/blog/DealingWithApplicationBaseURLsAndRazorLinkGenerationWhileHostingASPNETWebAppsBehindReverseProxies.aspx)

<b> My Minimum requirements </b>


    $ lsb_release -a
    No LSB modules are available.
    Distributor ID:	Ubuntu
    Description:	Ubuntu 18.04.4 LTS
    Release:	18.04
    Codename:	bionic


    $ sudo docker --version
    Docker version 19.03.9, build 9d988398e7

    $ sudo docker-compose --version
    docker-compose version 1.25.5, build 8a1c60f6

    $ dotnet --version
    3.1.300



## 1. Create a web frontend as a docker image


#### Create the site
We need a web project that we can utilise in a container. For simplicity, we choose the dotnet sample application

The `myhello-compose.yml` file:

```yml
version: "3.1"
services:

    myhello:
        image: mcr.microsoft.com/dotnet/core/samples:aspnetapp
        command:
            - "--entrypoints.web.address=:80"
        expose:
            - "80"
        labels:        
            - "traefik.http.routers.myhello.rule=PathPrefix(`/myhello`)"
            - "traefik.http.routers.myhello-route.entrypoints=web"
            - "traefik.http.middlewares.myhello-pathstrip.stripprefixregex.regex=/myhello"
            - "traefik.http.routers.myhello-middlew.middlewares=myhello-pathstrip@docker"
            - "traefik.enable=true"
```

`
expose:
    - "80"
`
 
 The dotnet sample app does not expose any ports so we need to specify that here so that we can access the container


``` "traefik.http.routers.myhello.rule=PathPrefix(`/myhello`)" ```

This will match any paths with the prefix `/myhello`

` - "traefik.http.middlewares.myhello-pathstrip.stripprefixregex.regex=/myhello"` 

Remove prefix `/myhello`

We need to remove the prefix /myhello from the path before passing it to the sample app because the sample app does not define `/myhello`. It will respond to the root (/). Therefore we need to send  `/myhello` from traefik to `/` in the sample app container.


` - "traefik.http.routers.myhello.middlewares=myhello-pathstrip@docker" `

Add the filter `myhello-pathstrip` as a middleware.

` - "traefik.enable=true" `

Make the container to be visible.



## 2. Wire it up with docker-compose


Now we need to assemble everything together and use traefik as a reverse proxy.

Create a file called `traefik-reverse-proxy-compose.yml`. In it, add the following content

```yml
version: "3.1"
services:
  traefik:
    image: traefik:v2.2
    command: 
        - "--api.insecure=true"
        - "--providers.docker=true"
        - "--providers.docker.exposedbydefault=false"
        - "--entrypoints.web.address=:80"
        - "--log=true"
        - "--log.This allowslevel=DEBUG" # (Default: error) DEBUG, INFO, WARN, ERROR, FATAL, PANIC
        - "--log.filepath=/trlogs/traefik2.log"
        - "--accesslog=true"
        - "--accesslog.filepath=/trlogs/traefik2_access.log"
  
                
    ports:
        - "80:80"
        # - "443:443"

  # Expose the Traefik web UI on port 8080. We restrict this
  # to localhost so that we don't publicly expose the
  # dashboard.
        - "127.0.0.1:8080:8080"
    volumes:
        - "/var/run/docker.sock:/var/run/docker.sock"
    labels:
        - "traefik.enable=false"
```

This will create the traefik container.


   



#### Start `traefik` container

    ~/myhello $ sudo docker-compose -f traefik-reverse-proxy-compose.yml up -d
    Starting myhello_traefik_1 ... done
    Attaching to myhello_traefik_1

    $

#### Start `myhello` container

```
    ~/myhello $ sudo docker-compose -f myhello-compose.yml up -d

    Starting myhello_myhello_1 ... done
    Attaching to myhello_myhello_1
    myhello_1  | warn: Microsoft.AspNetCore.DataProtection.Repositories.FileSystemXmlRepository[60]
    myhello_1  |       Storing keys in a directory '/root/.aspnet/DataProtection-Keys' that may not be persisted outside of the container. Protected data will be unavailable when container is destroyed.
    myhello_1  | info: Microsoft.Hosting.Lifetime[0]
    myhello_1  |       Now listening on: http://[::]:80
    myhello_1  | info: Microsoft.Hosting.Lifetime[0]
    myhello_1  |       Application started. Press Ctrl+C to shut down.
    myhello_1  | info: Microsoft.Hosting.Lifetime[0]
    myhello_1  |       Hosting environment: Production
    myhello_1  | info: Microsoft.Hosting.Lifetime[0]
    myhello_1  |       Content root path: /app

    $
```

Open the favourite browser and go to `http://localhost/myhello`



We should see something like this:


<img src="./myhello-site.png" alt="Screenshot of myhello site" />


The site does not have any css etc applied to it because the sample app returns the path to the css as `http://localhost/css/site.css` while we expect `http://localhost/myhello/css/site.css`.
Instructions on how to adjust that can be found [here](https://www.hanselman.com/blog/DealingWithApplicationBaseURLsAndRazorLinkGenerationWhileHostingASPNETWebAppsBehindReverseProxies.aspx)

We can shut the containers down with 

    ~/myhello $ sudo docker-compose -f myhello-compose.yml down
    Removing myhello_myhello_1 ... done
    Removing network myhello_default
    ERROR: error while removing network: network myhello_default id ea09ec58c03fcc28280b4580419b5fc7cd60453658423619417f90055ba20120 has active endpoints
    $

The error occurs because the traefik container is still using the network which is expected.

Shutting down `traefik`:

    ~/myhello $ sudo docker-compose -f traefik-reverse-proxy-compose.yml down
    Stopping myhello_frontend_1 ... done
    Removing myhello_frontend_1 ... done
    Removing network myhello_default
    $


## Helpful items ##

* Command to copy the traefik log files from the container to local the drive (requires traefik to be running): 

    ` sudo docker cp $(sudo docker container ps  | grep traefik |  awk '{ print $1}'):/trlogs . `
