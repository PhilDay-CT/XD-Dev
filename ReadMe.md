# Phil's XD Development repo

This repo include all of compose images and configuration files to run a development Cross Domain System.

In effect it is an example of the files created by following the instructions in [CrossDomain-Docker] (https://github.com/ConfiguredThings/CrossDomain-Docker)

The git configuration repository is : https://github.com/PhilDay-CT/XD-Dev-config

`docker-compose/` contains the files to run a "standard" cross domain system using the released images from [CrossDomain-Docker] (https://github.com/ConfiguredThings/CrossDomain-Docker)

`docker-compose-in423/` contains the files to run a "SISL" cross domain system using the released images from [IN423-xd](https://github.com/ConfiguredThings/IN423-xd).  These files are defined as extensions to the standard files in `docker-compose/`, showing that in general only the image has to be changed to create a SISL system.


## Basic Dev use case using local images

The main use is a 'mono' system using local images (i.e as part of a dev testing)

## Start the ops dockers
```
cd docker-compose
docker-compose -f dev/ops-local.yml up 
```

## Start the dockers for a "standard" system
```
cd docker-compose
docker-compose -f dev/mono-local.yml up 
```


## Start the dockers for a "SISL" system
```
cd docker-compose-in432
docker-compose -f dev/mono-local.yml up 
```

By editing the compose files in `docker-compose-in423/` various "SISL gateway" issues can be simulated:

- using the ctxd low_emulator image will send status as non-SISL data, which will be cloaked by the gateway
- using the ctxd-import-diode image will allow the non-SISL data to reach the high_import SISL_Receiver 

