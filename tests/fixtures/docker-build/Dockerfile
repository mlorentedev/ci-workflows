# The docker-build smoke's fixture (spec CI-010). The stamp layer holds a random
# id: the warm smoke reads the same stamp only if it restored the layer
# from the cache instead of running this step again.
FROM busybox:1.37.0@sha256:a7dbc319b1438115a207e11930dc4bb3e643dcb3ec0bdd694bb36cd8fad289ec
RUN cat /proc/sys/kernel/random/uuid > /stamp
CMD ["cat", "/stamp"]
