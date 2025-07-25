#!/bin/sh

# Remove the default memory values from the artemis.profile so they can be overridden with Helm values
echo "set java args"
sed -i "s#\-Xms512M\ \-Xmx2G# $MEM_ARG $HAWTIO_ARGS#g" $ARTEMIS_BROKER_HOME/etc/artemis.profile
# sed -i "s/0\.0\.0\.0/127.0.0.1/g" $ARTEMIS_BROKER_HOME/etc/jolokia-access.xml

# custom broker.xml must be mounted at /config/broker.xml
echo "set broker location"
sed -i "s/opt\/company-artemis\/etc\/\/broker.xml/config\/broker.xml/g" $ARTEMIS_BROKER_HOME/etc/bootstrap.xml

# sed -i "s#<binding name=\"artemis\" uri=\"http://0.0.0.0:8161\">#<binding name=\"artemis\" uri=\"http://0.0.0.0:8161\">#" $ARTEMIS_BROKER_HOME/etc/bootstrap.xml

# appends trailing slash if it isn't there
# matches the last character on the line if it's not /, then replaces it with the match + /
BASEPATH=$(echo "$BASEPATH" | sed 's#[^/]$#&/#')
# if slash at beginning of line replace it with nothing
BASEPATH=$(echo "$BASEPATH" | sed 's#^/##')
export BASEPATH

echo "set metrics url"
sed -i '/<\/binding>/ a \       <binding uri="http://0.0.0.0:8162">' $ARTEMIS_BROKER_HOME/etc/bootstrap.xml
sed -i '/<binding uri="http:\/\/0.0.0.0:8162">/ a \           <app url="metrics" war="metrics.war"\/>' $ARTEMIS_BROKER_HOME/etc/bootstrap.xml
sed -i '/<app url="metrics" war="metrics.war"\/>/ a \       </binding>' $ARTEMIS_BROKER_HOME/etc/bootstrap.xml

echo "set basePath changes"
#sed -i "s#<binding name=\"artemis\" uri=\"http://0.0.0.0:8161\">#<binding name=\"artemis\" uri=\"http://0.0.0.0:8161\">#g" $ARTEMIS_BROKER_HOME/etc/bootstrap.xml
sed -i "s#<app name=\"console\" url=\"console\" war=\"console.war\"/>#<app name=\"console\" url=\"${BASEPATH}console\" war=\"console.war\"/>#g" $ARTEMIS_BROKER_HOME/etc/bootstrap.xml
#sed -i "s#rootRedirectLocation=\"console\"#rootRedirectLocation=\"${BASEPATH}console\"#g" $ARTEMIS_BROKER_HOME/etc/bootstrap.xml
# allow external hosts access
sed -i "s/0\.0\.0\.0//" $ARTEMIS_BROKER_HOME/etc/jolokia-access.xml
#  If you use a TLS proxy that transforms secure requests to insecure requests (e.g. in a Kubernetes environment) then consider changing the proxy to preserve HTTPS and switching the embedded web server to HTTPS. If that isn’t feasible then you can accept the risk by adding <ignore-scheme/>
#  https://activemq.apache.org/components/artemis/documentation/latest/versions.html#upgrading-from-2-39-0
sed -i "s#</cors>#    <ignore-scheme/>\n    </cors>#" $ARTEMIS_BROKER_HOME/etc/jolokia-access.xml
# allow open login to console mixed with "ENV HAWTIO_ARGS "-Dhawtio.authenticationEnabled=false"
sed -i "s#<entry domain=\"hawtio\"/>#<entry domain=\"*\"/>#" $ARTEMIS_BROKER_HOME/etc/management.xml
