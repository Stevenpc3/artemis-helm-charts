ARG BUILD_IMAGE=cdn.harbor.company.com/ext.hub.docker.com/library/eclipse-temurin:17.0.13_11-jdk-alpine
ARG DEPLOY_IMAGE=cdn.harbor.company.com/ext.hub.docker.com/library/eclipse-temurin:17.0.13_11-jre-alpine

#
# Build stage
#
FROM ${BUILD_IMAGE} AS build

ARG HTTP_PROXY=http://proxy.company.com:80
ARG HTTPS_PROXY=http://proxy.company.com:80
ARG http_proxy=${HTTP_PROXY}
ARG https_proxy=${HTTPS_PROXY}

# Download, unpack, verify Artemis
# renovate: datasource=docker depName=apache/activemq-artemis
ENV ACTIVEMQ_ARTEMIS_VERSION=2.42.0
ENV WORK_DIR /opt/work
WORKDIR $WORK_DIR

COPY ./scripts/update-configs.sh /tmp/update-configs.sh

# Temporarily add certs
ADD http://company.com/trust/pem/combined/Combined_pem.pem /usr/local/share/ca-certificates/Combined.crt

RUN SSL_CERT_FILE=/usr/local/share/ca-certificates/Combined.crt \
     apk add --no-cache ca-certificates curl openssl libaio && update-ca-certificates

RUN apk upgrade --no-cache

RUN curl -sL \
    https://archive.apache.org/dist/activemq/activemq-artemis/${ACTIVEMQ_ARTEMIS_VERSION}/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.sha512 \
    -o apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.sha512 && \
    curl -sL \
    https://archive.apache.org/dist/activemq/activemq-artemis/${ACTIVEMQ_ARTEMIS_VERSION}/apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz \
    -o apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz

RUN sha512sum -c apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz.sha512 && \
  #echo "\"$checksum\" apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz" | sha512sum -c - || (echo 'checksum failed' && exit 1) && \
  tar xfz apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION}-bin.tar.gz && \
  ln -s apache-artemis-${ACTIVEMQ_ARTEMIS_VERSION} artemis

#
# Runtime stage
#
FROM ${DEPLOY_IMAGE} AS runtime

ENV ARTEMIS_BROKER_HOME /opt/company-artemis
RUN mkdir $ARTEMIS_BROKER_HOME

ENV MEM_ARG "-Xms200m -Xmx512m"
ENV HAWTIO_ARGS "-Dhawtio.authenticationEnabled=false"
ENV BASEPATH "/"

# copy files from build stage
RUN mkdir /opt/apache-artemis
COPY --from=build /opt/work/artemis /opt/apache-artemis/
COPY --from=build /usr/bin/openssl /usr/bin/openssl
COPY --from=build /usr/lib/libaio.so.* /usr/lib/
COPY --from=build /tmp/update-configs.sh $ARTEMIS_BROKER_HOME/tmp/update-configs.sh

# Setup Artemis user permissons
ENV ARTEMIS_USER=992
ENV ARTEMIS_GROUP=992
RUN /usr/sbin/addgroup -g $ARTEMIS_GROUP artemis && /usr/sbin/adduser -D -u $ARTEMIS_USER -G artemis artemis

# Configure Artemis https://activemq.apache.org/components/artemis/documentation/latest/using-server.html
RUN cd /opt && /opt/apache-artemis/bin/artemis create company-artemis \
    --allow-anonymous \
    --home /opt/apache-artemis \
    --host 0.0.0.0 \
    --http-host 0.0.0.0 \
    --relax-jolokia \
    --no-hornetq-acceptor \
    --no-mqtt-acceptor \
    --no-stomp-acceptor \
    --silent

# Unfortunately the lock and tmp files that Artemis generates cannot exist anywhere other than this directory.
# So, give it wide open permissions so this image can be run as any user.
RUN mkdir $ARTEMIS_BROKER_HOME/lock
RUN chmod 777 $ARTEMIS_BROKER_HOME/lock $ARTEMIS_BROKER_HOME/tmp $ARTEMIS_BROKER_HOME/etc $ARTEMIS_BROKER_HOME/tmp/update-configs.sh

# copy libraries needed for metrics gathering
COPY plugins/artemis-prometheus-metrics-plugin-3.2.0.jar $ARTEMIS_BROKER_HOME/lib
RUN mkdir $ARTEMIS_BROKER_HOME/web
COPY plugins/metrics.war $ARTEMIS_BROKER_HOME/web

# Port for CORE, OPENWIRE, STOMP
EXPOSE 61616
EXPOSE 61613

#Port for AMQP
EXPOSE 5672

#Port for Web Console
EXPOSE 8161

#Port for metrics
EXPOSE 8162

# Expose some volumes
VOLUME ["${ARTEMIS_BROKER_HOME}/data"]
VOLUME ["${ARTEMIS_BROKER_HOME}/tmp"]
VOLUME ["${ARTEMIS_BROKER_HOME}/etc"]

WORKDIR ${ARTEMIS_BROKER_HOME}/bin
USER artemis

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["$ARTEMIS_BROKER_HOME/tmp/update-configs.sh && ${ARTEMIS_BROKER_HOME}/bin/artemis run"]
