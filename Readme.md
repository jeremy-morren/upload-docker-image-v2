## Upload docker image to registry via HTTP api

This is a powershell script (tested on ubuntu) that uploads a docker image archive (from `docker save`) to an image registry via HTTP. It can be used in an environment where `docker` is not available. 

It does not have support for authentication as yet. I use it to upload images to a MicroK8s container registry from within a pod (without needing to expose the docker daemon to pods). 

Usage (full docker save shown): 
```
docker pull alpine:latest
docker tag alpine:latest my-alpine:latest
docker tag alpine:latest my-alpine:1.0
docker save my-alpine:latest my-alpine:1.0 -o alpine.tar.gz
.\upload-image.ps1 -Remote http://localhost:32000/ -Archive alpine.tar.gz
```

Example output:
```
Uploading repository my-alpine
Layer 25fe74d3f1f6ccd36452f82043bd02b6b0ce82b6efaece7ee3b8fee9ef1acdc6/layer.tar already exists, skipping
Uploaded layer c059bfaa849c4d8e4aecaeb3a10c2d9b3d85f5165c66ad3a4d937758128c4d18.json
Uploaded my-alpine:latest manifest
Uploaded my-alpine:1.0 manifest
Successfully Uploaded repository my-alpine!
Complete!