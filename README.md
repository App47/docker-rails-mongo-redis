
Docker Image
============

To support the General testing container, use redis and mongo containers provided by circle CI 

* Ubuntu 20
* Java 8
* Ruby 2.7.0


Docker commands that are useful
===============================

1. `docker build .` to build the current version
2. `docker login --username=%USERNAME%` to log into docker hub
2. `docker images` to list the images, with the most recent being at the top.
3. `docker tag %IMAGE ID% app47/focal:latest` to tag the local image
4. `docker push app47/focal` to push to the hub, this tag can then be used in circle ci files or other places.
