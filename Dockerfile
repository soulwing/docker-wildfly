ARG JRE_VERSION=11-jre-slim

FROM debian:latest AS builder

ARG WILDFLY_VERSION=17.0.0.Final
ARG WILDFLY_URL=http://search.maven.org/remotecontent?filepath=org/wildfly/wildfly-dist/${WILDFLY_VERSION}/wildfly-dist-${WILDFLY_VERSION}.tar.gz
ARG S6_VERSION=v1.21.4.0
ARG S6_REPO=https://github.com/just-containers/s6-overlay/releases/download
ARG S6_URL=${S6_REPO}/${S6_VERSION}/s6-overlay-amd64.tar.gz

ADD ${S6_URL} /tmp/s6-overlay.tar.gz
ADD ${WILDFLY_URL} /tmp/wildfly.tar.gz

RUN \
    mkdir /tmp/s6 && \
    tar -C /tmp/s6 -zxf /tmp/s6-overlay.tar.gz && \
    mkdir /tmp/wildfly && \
    tar -C /tmp/wildfly -zxf /tmp/wildfly.tar.gz

FROM openjdk:${JRE_VERSION}

ARG CONFIG_DIR=/etc/wildfly/config.d/
ARG APPS_BASE=/apps

ENV WILDFLY_USER=wildfly \
    WILDFLY_HOME=${APPS_BASE}/wildfly \
    WILDFLY_RUNTIME_BASE_DIR=/run/wildfly \
    WILDFLY_BIND_INTERFACE=eth0 \
    WILDFLY_HA=false

ENV WILDFLY_BIND_ADDRESS=${WILDFLY_RUNTIME_BASE_DIR}/configuration/bind_address
ENV WILDFLY_MGMT_BIND_ADDRESS=${WILDFLY_RUNTIME_BASE_DIR}/configuration/mgmt_bind_address

RUN \
    apt-get update && \
    apt-get install -y iproute2 && \
    rm -fr /var/lib/apt/lists/*

COPY --from=builder /tmp/s6 /
COPY --from=builder /tmp/wildfly ${APPS_BASE}/
RUN ln -s ${APPS_BASE}/wildfly-* ${WILDFLY_HOME}

COPY run-wildfly.sh ${WILDFLY_HOME}/bin/run-wildfly
COPY run-jboss-cli.sh ${WILDFLY_HOME}/bin/run-jboss-cli
COPY cont-init.d/ /etc/cont-init.d/

RUN \
  adduser --disabled-password --no-create-home --home "${WILDFLY_HOME}" \
      --gecos "Wildfly User" --shell "/bin/bash" ${WILDFLY_USER} && \
  mv ${WILDFLY_HOME}/standalone ${WILDFLY_HOME}/standalone.OEM && \
  ln -s ${WILDFLY_RUNTIME_BASE_DIR} ${WILDFLY_HOME}/standalone && \
  mkdir -p $CONFIG_DIR && \
  chmod 755 ${WILDFLY_HOME}/bin/run-wildfly && \
  chmod 755 ${WILDFLY_HOME}/bin/run-jboss-cli && \
  ln -s ${WILDFLY_HOME}/bin/run-jboss-cli /usr/local/bin/cli

EXPOSE 8080 9990
ENTRYPOINT ["/init"]
CMD ["/apps/wildfly/bin/run-wildfly"]
