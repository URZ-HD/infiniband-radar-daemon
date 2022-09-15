FROM debian:buster-slim as builder

ENV TZ="Europe/Berlin" \
    API_SERVER="127.0.0.1:443/api" \
    API_TOKEN="foo" \
    FABRIC_ID="bar" \
# to allow mapping IB device with external device list 
    DAEMONHOST="node1"

RUN apt update && \
    apt install -y wget
    
# using bullseye curl 7.74, because 7.64.0 (buster) has some http/2 issues which leads to random container restarts
# https://github.com/kubernetes/ingress-nginx/issues/4679#issuecomment-878867842
# https://stackoverflow.com/questions/56865217/php-curl-error-http-2-stream-0-was-not-closed-cleanly-protocol-error-err-1
RUN wget http://ftp.de.debian.org/debian/pool/main/c/curl/libcurl4_7.74.0-1.3+deb11u3_amd64.deb 
RUN wget http://ftp.de.debian.org/debian/pool/main/c/curl/libcurl4-openssl-dev_7.74.0-1.3+deb11u3_amd64.deb 

RUN apt update && \
    apt install -y cmake make g++ libibverbs-dev libibnetdisc-dev libibmad-dev libopensm-dev \
    /libcurl4-openssl-dev_7.74.0-1.3+deb11u3_amd64.deb /libcurl4_7.74.0-1.3+deb11u3_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /project/code
COPY CMakeLists.txt ./
COPY src/ ./src
COPY 3d_party  ./3d_party

WORKDIR /project/code/build
RUN cmake .. && cmake --build . --target infiniband_radar_daemon -- -j 2

FROM debian:buster-slim

COPY --from=builder /project/code/build/infiniband_radar_daemon /usr/sbin/infiniband_radar_daemon
COPY --from=builder /libcurl4_7.74.0-1.3+deb11u3_amd64.deb /

RUN apt update && \
    apt install -y libibnetdisc5 \
    /libcurl4_7.74.0-1.3+deb11u3_amd64.deb && \
    rm -f /libcurl4_7.74.0-1.3+deb11u3_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint-daemon.sh /entrypoint-daemon.sh
COPY ibdevices.lst /config/ibdevices.lst
COPY ib_topology.map /config/ib_topology.map

VOLUME /config
WORKDIR /config
# using entrypoint script, to build up configuration via ENV Vars
ENTRYPOINT ["/entrypoint-daemon.sh"]
