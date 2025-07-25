# artemis

[ Chart version `7.1.0` ][ App version `2.42.0` ]

Apache ActiveMQ Artemis message broker

This chart deploys a single live instance or a live and backup instance in HA mode using replication.

This chart includes a default broker.xml, however a custom broker.xml can be used as described below.

## HA

In HA mode services connect to artemis-ha as it would a single artemis instance because third service routes all connections to the ha instance services.
This ensures a transparent connection in ha mode or non ha modes.

To enable ha set `ha.enabled=true`

HA alone can result in split brain.  There are several ways to prevent split brain https://activemq.apache.org/components/artemis/documentation/latest/network-isolation.html

Zookeeper is offered as a solution to split brain.  It is disabled by default to allow the option for other mitigation methods if desired.

To enable Zookeeper set `zookeeper-bitnami.enabled=true` when using ha mode.

## Queue and Topic matchers

The default `broker.xml` is configured to match queues and topics with a particular format.

### Queues

Any address that matches `queue.*` will be automatically configured as a queue in Artemis.

The benefits you get from this are as follows:

- If a queue doesn't have an active consumer, there will be no queue defined in artemis.
- If a producer sends a message to the queue with no consumers, a queue will be automatically created with that message
    iff the message is marked as durable.
    - If the message is not marked as durable, the message will not be able to be consumed by any potential consumer.
- If a consumer detaches from a queue, and the queue has 0 messages on it, artemis will remove it from the list
    until a consumer attaches to the queue, or a produces sends a durable message to the queue.

### Topics

Any address that matches `topic.*` will be automatically configured as a topic in Artemis.

## Using a different broker.xml
A custom broker.xml file can be used by overriding the `configMaps.live.broker` and `configMaps.backup.broker` values to instruct the Artemis pod to reference a different ConfigMap. The ConfigMap must contain the following keys:

* `broker.xml` - The broker.xml file content

For example, assuming the `my-artemis-live-broker.yaml` file contains a ConfigMap named `MyArtemisLiveBroker` and `my-artemis-backup-broker.yaml` file contains a ConfigMap named `MyArtemisBackupBroker`:

```bash
kubectl apply -f my-artemis-live-broker.yaml
kubectl apply -f my-artemis-backup-broker.yaml
helm upgrade -i artemis repo/artemis --set configMaps.live.broker=MyArtemisLiveBroker --set configMaps.backup.broker=MyArtemisBackupBroker
```

## Prometheus Metrics
Enabling metrics will enable the metrics endpoint.  If you enable serviceMonitor this will allow promethues to scrape the metrics at that endpoint.

set `metrics.enabled=true` and `metrics.serviceMonitor.enabled=true`
Metrics are made available using the [artemis-prometheus-metrics-plugin](https://github.com/rh-messaging/artemis-prometheus-metrics-plugin) plugin.  This plugin makes use of ActiveMQ [metrics interface](https://activemq.apache.org/components/artemis/documentation/latest/metrics.html) to make data available to a [Promtheus Instance](https://github.com/prometheus-operator/prometheus-operator) such as one provided by [Rancher](https://rancher.com/docs/rancher/v2.5/en/monitoring-alerting/configuration/servicemonitor-podmonitor/) using a [Service Monitor](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#servicemonitorspec).  Set up examples can be found [here](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/running-exporters.md).

The metrics are made available via the metrics endpoint that Prometheus will scrape based on the configuration of the monitor.  These values are stored in Prometheus and made available for query or integration with tools like Grafana.

A [servicemonitor](templates/service-monitor.yaml) can be enabled to configure metrics scraping with Prometheus.

***Metrics are disabled by default.***

Please see values for a list of metrics to enable

## Management Console
The [Management console](https://activemq.apache.org/components/artemis/documentation/latest/management-console.html) allows in depth views of broker instances.

### Local
To connect to the console you can port forward with

```kubectl port-forward artemis-ha-live-0 32000:8161 --address='0.0.0.0'```

Make sure the '32000' matches a port you have exposed and the 'artemis-ha-live-0' is the name of the pod you wish to expose.
Passing the --address='0.0.0.0' should match the 'http-host' which is currently set to '0.0.0.0' in the [Dockerfile](../../images/artemis/Dockerfile)

Then connect with a browser at

```http://127.0.0.1:32000/<Values.basePath>/console``` (basePath defaults to `/`)

Where the port matches to forwarded port and the address matches the address set in the 'jolokia-access.xml' which is currently 127.0.0.1 in the [Dockerfile](../../images/artemis/Dockerfile)

More about configuring Artemis can be found at [Using Server](https://activemq.apache.org/components/artemis/documentation/latest/using-server.html)

### Ingress

You can enable ingress which will expose the service without port forward.  See enabling oAuth2 below.

Connect to the browser through ingress at:

```<domain>/<Values.basePath>/console``` (basePath defaults to `/` unless overridden)

If extra protection of the management console is needed, then the oAuth2 sidecar can be enabled. The oAuth2
sidecar acts as a security proxy in front of the artemis service and enforces user authentication before reaching
the management console. This method can work with any valid provider including Keycloak, Azure, Google, GitHub, and more.

Official docs [here](https://oauth2-proxy.github.io/oauth2-proxy/docs/behaviour)

See the Oauth overrides in the [values.yaml](./values.yaml) file.

You can use existing secrets from the cluster for oAuth by passing a template like

```YAML
oAuthSidecar:
  enabled: true
  oauthSecretName: '\{\{ include "helper.oauthSecret" . \}\}'  <--- do not include the \ (used to escape the doc generation)
```

## Enable TLS
Enable TLS on the acceptor by setting .Values.acceptors.artemis.tls.enabled to true.

### Requirements
* `Kubernetes secret containing a password for the keystore and the server’s public and private keys in PEM format.`

### Example with Assumptions
* `The file artemis-tls.key is the private key
* `The file artemis-tls.crt is the public key
* `The cert has a common name of artemis.`
* `The server cert was signed by a CA trusted by clients.`
* `The storepass 'changeit' will be used to create artemis-tls.p12.`

#### Value overrides
``` yaml
acceptors:
  artemis:
    tls:
      #when false, do not render tls key/values into acceptors defined in /config/broker.xml
      enabled: true
      secret:
        #name of k8 secret containing your keystore and the keystore's password
        name: "artemis-tls"
        key:
          #filename of private key
          private: "artemis-tls.key"
          #filename of public key
          public: "artemis-tls.crt"
          #The key in the k8 secret related to keystore's password, not 'changeit'.
          password: "password"
      enabledProtocols: "TLSv1.3"
 ```
#### Secret Creation

``` bash
kubectl create secret generic artemis-tls --from-file=./artemis-tls.key ---from-file=./artemis-tls.crt --from-literal=password=changeit
```
#### Result in pod:
* `rendered values in /config/broker.xml`
```
<acceptor name="artemis">
  tcp://0.0.0.0:61616?
  sslEnabled=true;
  keyStorePath=/opt/company-artemis/keystore/artemis-tls.p12;
  keyStorePassword=${keyStorePassword};
  keyStoreType=PKCS12;
```
* `environment variable used in /config/broker.xml by keyStorePassword=${keyStorePassword};`
``` bash
env | grep keyStorePassword
keyStorePassword=changeit
```

## Authentication with Login
By default `.Values.auth.requireLogin` is set to true. This makes all connections to our Artemis broker require a username and password.

### Requirements
These charts define two secrets, a server side and client side secret.
The client secret is [kubernetes basic auth](https://kubernetes.io/docs/concepts/configuration/secret/#basic-authentication-secret), override it with `.Values.auth.clientSecret`.

Override the server secret with `.Values.auth.serverSecret`. The username and password of the server and client secrets must match.

***The server secret must be in the following format:***
```
USERPASS: <username> = <password>
```
**Example for generating:**
```
$ echo -n "username = password" | base64
dXNlcm5hbWUgPSBwYXNzd29yZA==
```

This gets mounted as an Artemis configuration file containing exactly the value in that key. The spaces around the equals sign *do matter*.

**need to add a link to the artemis secrets in repo**

If you don't point to your own defined secret, `.Values.auth.username` and `.Values.auth.password` must be set which templates the default secrets `templates/artemis-client-secret.yaml` and `/templates/artemis-server-secret.yaml`. These should be plaintext in the values.yaml as they get base64 encoded.

### Users and Roles
The `config/roles.properties` file defines what roles a user has, as `<role name>=<comma separated list of usernames>`, for example:

```
amq=user
```

Which gives the username `user` the role `amq`.

Role permissions are defined in the `broker.xml` under `security-settings`. The permissions available to each role can be changed under `.Values.auth.permissions`.

Please see the Artemis security docs [here](https://activemq.apache.org/components/artemis/documentation/latest/security.html#propertiesloginmodule) for more info.

Example of the permissions in the `broker.xml`:

``` xml
      <security-settings>
         <security-setting match="#">
            <permission type="createNonDurableQueue" roles="amq"/>
            <permission type="deleteNonDurableQueue" roles="amq"/>
            <permission type="createDurableQueue" roles="amq"/>
            <permission type="deleteDurableQueue" roles="amq"/>
            <permission type="createAddress" roles="amq"/>
            <permission type="deleteAddress" roles="amq"/>
            <permission type="consume" roles="amq"/>
            <permission type="browse" roles="amq"/>
            <permission type="send" roles="amq"/>
            <!-- we need this otherwise ./artemis data imp wouldn't work -->
            <permission type="manage" roles="amq"/>
         </security-setting>
      </security-settings>
```

***The username in `roles.properties` must match the one defined in the Kubernetes Secret.*** Please see Artemis authentication docs [here](https://activemq.apache.org/components/artemis/documentation/latest/security.html#propertiesloginmodule).

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| acceptors.artemis.anycastPrefix | string | `"anycast://"` | The anycastPrefix for the artemis acceptor. See https://activemq.apache.org/components/artemis/documentation/latest/address-model.html#using-prefixes-to-determine-routing-type |
| acceptors.artemis.multicastPrefix | string | `"multicast://"` | The multicastPrefix for the artemis acceptor. See https://activemq.apache.org/components/artemis/documentation/latest/address-model.html#using-prefixes-to-determine-routing-type |
| acceptors.artemis.tls | object | `{"enabled":false,"enabledCipherSuites":"","enabledProtocols":"","secret":{"key":{"password":"","private":"","public":""},"name":""}}` | Enable TLS |
| acceptors.artemis.tls.enabledCipherSuites | string | `""` | Optional comma separated list of cipher suites used for TLS communication. Ex: "TLS_AES_256_GCM_SHA384" |
| acceptors.artemis.tls.enabledProtocols | string | `""` | Optional comma separated list of protocols used for TLS communication. Ex: "TLSv1.3" |
| acceptors.artemis.tls.secret | object | `{"key":{"password":"","private":"","public":""},"name":""}` | TLS requires a secret containing a keystore |
| acceptors.artemis.tls.secret.key.password | string | `""` | Key required to retrieve the keystore's password from secret |
| acceptors.artemis.tls.secret.key.private | string | `""` | Key required to retrieve the private key used to generate keystore in initContainer |
| acceptors.artemis.tls.secret.key.public | string | `""` | Key required to retrieve the public key used to generate keystore in initContainer |
| acceptors.artemis.tls.secret.name | string | `""` | Name of secret with keystore and optionally its password |
| acceptors.stomp.anycastPrefix | string | `"/queue/"` | The anycastPrefix for the stomp acceptor. see https://activemq.apache.org/components/artemis/documentation/latest/stomp.html#configuring-routing-semantics-from-the-broker-side |
| acceptors.stomp.multicastPrefix | string | `"/topic/"` | The multicastPrefix for the stomp acceptor. see https://activemq.apache.org/components/artemis/documentation/latest/stomp.html#configuring-routing-semantics-from-the-broker-side |
| addressSettings.deadLetterQueue | object | `{"addressFullPolicy":"DROP","expiryDelay":-1,"maxSizeBytes":50000000,"name":"deadLetterQueue","purgeOnNoConsumers":true}` | Dead Letter Queue. https://activemq.apache.org/components/artemis/documentation/latest/undelivered-messages.html#dead-letter-addresses |
| addressSettings.deadLetterQueue.maxSizeBytes | int | `50000000` | Max size of a specific address in Bytes. |
| addressSettings.expiryAddress | object | `{"addressFullPolicy":"DROP","maxSizeBytes":50000000,"name":"ExpiryQueue","purgeOnNoConsumers":true}` | Expiry Queue. https://activemq.apache.org/components/artemis/documentation/latest/message-expiry.html#message-expiry |
| addressSettings.expiryAddress.maxSizeBytes | int | `50000000` | Max size of a specific address in Bytes. |
| addressSettings.messageCounterHistoryDayLimit | int | `10` | Days to keep counter details |
| addressSettings.pageLimits | object | `{"enabled":false,"pageFullPolicy":"FAIL","pageLimitBytes":"1G"}` | Paging limitations for the "#" address. https://activemq.apache.org/components/artemis/documentation/latest/paging.html#page-limits-and-page-full-policy |
| backup.persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| backup.persistence.dynamic | bool | `true` |  |
| backup.persistence.enabled | bool | `true` |  |
| backup.persistence.mountPath | string | `"/opt/company-artemis/data"` |  |
| backup.persistence.name | string | `"storage"` |  |
| backup.persistence.size | string | `"1G"` |  |
| backup.persistence.static.name | string | `"artemis"` |  |
| backup.persistence.subPathSuffix | string | `"artemis"` |  |
| basePath | string | `"/"` |  |
| configMaps | object | `{"backup":{"broker":""},"live":{"broker":""},"logging":"","login":"","roles":""}` | You can create and deploy a Configmap that contains a broker.xml similar to the /config/broker-live.xml and have Artemis use that broker. |
| configMaps.backup.broker | string | `""` | the name of a ConfigMap containing the artemis backup instance broker.xml file to use instead of the built-in one |
| configMaps.live.broker | string | `""` | the name of a ConfigMap containing the artemis live instance broker.xml file to use instead of the built-in one |
| configMaps.logging | string | `""` | the name of a ConfigMap containing the artemis logging.properties file to use instead of the built-in one |
| configMaps.login | string | `""` | the name of a ConfigMap containing the artemis login.config file to use instead of the built-in one |
| configMaps.roles | string | `""` | the name of a ConfigMap containing the artemis roles.properties file to use instead of the built-in one |
| extraAddressSettings | string | `nil` | Extra address-settings to set in artemis.  Will be appended to the current settings. https://activemq.apache.org/components/artemis/documentation/latest/address-settings.html#address-settings |
| extraAddresses | string | `nil` | Extra addresses to create in artemis. https://activemq.apache.org/components/artemis/documentation/latest/index.html#addressing |
| extraResourceLimitSettings | string | `nil` |  |
| ha | object | `{"backup":{"allowFailBack":false,"maxSavedReplicatedJournalsSize":0},"enabled":false,"primary":{"checkForActiveServer":true}}` | Put artemis in HA mode and deploy multiple Artemis instances in replication mode. |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"repo/helm-charts/artemis"` |  |
| image.tag | string | `"2.42.0-0"` |  |
| ingress.annotations."nginx.ingress.kubernetes.io/proxy-body-size" | string | `"200m"` |  |
| ingress.annotations."nginx.ingress.kubernetes.io/proxy-read-timeout" | string | `"3600"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.rules[0].paths[0].path | string | `"{{ .Values.basePath }}"` |  |
| ingress.rules[0].paths[0].serviceName | string | `"{{ include \"company/common/names/fullname\" . }}"` |  |
| ingress.rules[0].paths[0].servicePort | int | `8161` |  |
| jvm.args | string | `"-Dlog4j2.configurationFile=file:/config/logging.properties"` | additional jvm args appended to the artemis startup command |
| jvm.memory | string | `"1500m"` | jvm heap size. Passed as a jvm options `-Xmx` and `-Xms` |
| live.persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| live.persistence.dynamic | bool | `true` |  |
| live.persistence.enabled | bool | `true` |  |
| live.persistence.mountPath | string | `"/opt/company-artemis/data"` |  |
| live.persistence.name | string | `"storage"` |  |
| live.persistence.size | string | `"1G"` |  |
| live.persistence.static.name | string | `"artemis"` |  |
| live.persistence.subPathSuffix | string | `"artemis"` |  |
| livenessProbe | object | `{"enabled":true,"spec":{"failureThreshold":1,"initialDelaySeconds":5,"periodSeconds":30,"tcpSocket":{"port":8161},"timeoutSeconds":5}}` | livenessProbe will check the management console that is always up in live or backup mode. |
| logging.audit.level | string | `"OFF"` | sets the level for which audit logs will be produced. May be configured with one of TRACE, DEBUG, INFO, WARN, ERROR, ALL or OFF. Set to INFO for STIG recommended audit logging |
| logging.events | object | `{"all":false,"connection":true,"consumer":false,"delivering":false,"internal":false,"sending":false,"session":true}` | STIG recommended audit logging defaults |
| logging.events.all | bool | `false` | Includes all the events. |
| logging.events.connection | bool | `true` | Connection is created/destroy. |
| logging.events.consumer | bool | `false` | Consumer is created/closed |
| logging.events.delivering | bool | `false` | Message is delivered to a consumer and when a message is acknowledged by a consumer. |
| logging.events.internal | bool | `false` | When a queue created/destroyed, when a message is expired, when a bridge is deployed and when a critical failure occurs. |
| logging.events.sending | bool | `false` | When a message has been sent to an address and when a message has been routed within the broker. |
| logging.events.session | bool | `true` | Session is created/closed. |
| login.clientSecret | string | `"{{ include \"company/common/names/fullname\" . }}-client-secret"` |  |
| login.password | string | `"password"` |  |
| login.requireLogin | bool | `true` |  |
| login.roles.browse | string | `"amq"` |  |
| login.roles.consume | string | `"amq"` |  |
| login.roles.createAddress | string | `"amq"` |  |
| login.roles.createDurableQueue | string | `"amq"` |  |
| login.roles.createNonDurableQueue | string | `"amq"` |  |
| login.roles.deleteAddress | string | `"amq"` |  |
| login.roles.deleteDurableQueue | string | `"amq"` |  |
| login.roles.deleteNonDurableQueue | string | `"amq"` |  |
| login.roles.manage | string | `"amq"` |  |
| login.roles.send | string | `"amq"` |  |
| login.serverSecret | string | `"{{ include \"company/common/names/fullname\" . }}-server-secret"` |  |
| login.username | string | `"user"` |  |
| metrics.enabled | bool | `false` | Metrics for all addresses and queues are enabled by default. If you want to disable metrics for a particular address or set of addresses you can do so by setting the enable-metrics address-setting to false. Optional metrics described at https://activemq.apache.org/components/artemis/documentation/latest/metrics.html#optional-metrics |
| metrics.fileDescriptors.enabled | bool | `false` | Gauges current and max-allowed open files. |
| metrics.jvm.gc.enabled | bool | `false` | JVM garbage collection data will be available to query |
| metrics.jvm.memory.enabled | bool | `false` | JVM memory data will be available to query |
| metrics.jvm.threads.enabled | bool | `false` | JVM thread data will be available to query |
| metrics.logging.enabled | bool | `false` | Counts the number of logging events per logging category (e.g. WARN, ERROR, etc.).  Works exclusively with Log4j2 |
| metrics.nettyPool.enabled | bool | `false` | Collects metrics from Netty’s PooledByteBufAllocatorMetric. |
| metrics.processor.enabled | bool | `false` | Gauges system CPU count, CPU usage, and 1-minute load average as well as process CPU usage. |
| metrics.securityCaches.enabled | bool | `false` | The following authentication & authorization cache metrics are exported. They are all tagged by cache (either authentication or authorization). Additional tags are noted cache.size, cache.puts, cache.gets tagged by result - either hit or miss, cache.evictions, cache.eviction.weight |
| metrics.serviceMonitor | object | `{"enabled":false,"fallbackScrapeProtocol":"PrometheusText0.0.4","interval":10}` | Will send metrics to Prometheus instance. |
| metrics.serviceMonitor.enabled | bool | `false` | Enable the [serviceMonitor](templates/service-monitor.yaml) |
| metrics.serviceMonitor.interval | int | `10` | Interval in seconds for the monitor service to scrape for metrics |
| metrics.uptime.enabled | bool | `false` | Gauges process start time and uptime. |
| oAuthSidecar.args[0] | string | `"--config"` |  |
| oAuthSidecar.args[1] | string | `"/etc/oauth2-proxy/oauth2.conf"` |  |
| oAuthSidecar.args[2] | string | `"show-debug-on-error=true"` |  |
| oAuthSidecar.config | bool | `false` |  |
| oAuthSidecar.containerPort | int | `4180` |  |
| oAuthSidecar.enabled | bool | `false` |  |
| oAuthSidecar.extraConfigmapMounts[0].mountPath | string | `"/etc/oauth2-proxy"` |  |
| oAuthSidecar.extraConfigmapMounts[0].name | string | `"{{ include \"company/artemis/oauthConfName\" . }}"` |  |
| oAuthSidecar.keycloak | object | `{"clientID":"","clientSecret":"","cookieSecret":"SECRETSECRETSECR","cookieSecure":true,"emailDomain":"*","oauth2proxy":{"pullPolicy":"IfNotPresent","registry":"cdn.harbor.company.com","repository":"ext.quay.io/oauth2-proxy/oauth2-proxy","tag":"v7.8.2"},"realm":"","url":""}` | Keycloak values for oAuth integration/deployment |
| oAuthSidecar.keycloak.clientID | string | `""` | ClientID for keycloak, required Value if using oAuthSidecar |
| oAuthSidecar.keycloak.clientSecret | string | `""` | ClientSecret for Keycloak, required Value if using oAuthSidecar |
| oAuthSidecar.keycloak.cookieSecret | string | `"SECRETSECRETSECR"` | CookieSecret - required if cookieSecure is true |
| oAuthSidecar.keycloak.cookieSecure | bool | `true` | CookieSecure - boolean value that is required for the cookie secret |
| oAuthSidecar.keycloak.emailDomain | string | `"*"` | emailDomain for Keycloak, required value |
| oAuthSidecar.keycloak.oauth2proxy.pullPolicy | string | `"IfNotPresent"` | Oauth2Proxy image pull policy |
| oAuthSidecar.keycloak.oauth2proxy.registry | string | `"cdn.harbor.company.com"` | Oauth2Proxy image registry |
| oAuthSidecar.keycloak.oauth2proxy.repository | string | `"ext.quay.io/oauth2-proxy/oauth2-proxy"` | Oauth2Proxy image repository |
| oAuthSidecar.keycloak.oauth2proxy.tag | string | `"v7.8.2"` | Oauth2Proxy image tag |
| oAuthSidecar.keycloak.realm | string | `""` | Realm for keycloak, required Value if using oAuthSidecar |
| oAuthSidecar.keycloak.url | string | `""` | Location of URL for keycloak instance, required value if using oAuthSidecar |
| oAuthSidecar.livenessProbe.enabled | bool | `true` |  |
| oAuthSidecar.livenessProbe.failureThreshold | int | `2` |  |
| oAuthSidecar.livenessProbe.httpGet.path | string | `"/ping"` |  |
| oAuthSidecar.livenessProbe.httpGet.port | int | `4180` |  |
| oAuthSidecar.livenessProbe.httpGet.scheme | string | `"HTTP"` |  |
| oAuthSidecar.livenessProbe.initialDelaySeconds | int | `5` |  |
| oAuthSidecar.livenessProbe.periodSeconds | int | `30` |  |
| oAuthSidecar.livenessProbe.successThreshold | int | `1` |  |
| oAuthSidecar.livenessProbe.timeoutSeconds | int | `5` |  |
| oAuthSidecar.oauthSecretName | string | `"keycloak-client-secrets"` |  |
| oAuthSidecar.readinessProbe.enabled | bool | `true` |  |
| oAuthSidecar.readinessProbe.failureThreshold | int | `1` |  |
| oAuthSidecar.readinessProbe.httpGet.path | string | `"/ready"` |  |
| oAuthSidecar.readinessProbe.httpGet.port | int | `4180` |  |
| oAuthSidecar.readinessProbe.httpGet.scheme | string | `"HTTP"` |  |
| oAuthSidecar.readinessProbe.initialDelaySeconds | int | `5` |  |
| oAuthSidecar.readinessProbe.periodSeconds | int | `30` |  |
| oAuthSidecar.readinessProbe.successThreshold | int | `1` |  |
| oAuthSidecar.readinessProbe.timeoutSeconds | int | `5` |  |
| oAuthSidecar.redisSessions | bool | `false` | Use redis as session store instead of cookies (see [Troubleshooting](#Troubleshooting) section) |
| oAuthSidecar.resources.limits.memory | string | `"512M"` |  |
| oAuthSidecar.resources.requests.cpu | string | `"500m"` |  |
| oAuthSidecar.resources.requests.memory | string | `"512M"` |  |
| oAuthSidecar.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | oAuthSidecar container security context |
| oAuthSidecar.startupProbe.enabled | bool | `false` |  |
| oAuthSidecar.startupProbe.failureThreshold | int | `1` |  |
| oAuthSidecar.startupProbe.httpGet.path | string | `"/ping"` |  |
| oAuthSidecar.startupProbe.httpGet.port | int | `4180` |  |
| oAuthSidecar.startupProbe.httpGet.scheme | string | `"HTTP"` |  |
| oAuthSidecar.startupProbe.initialDelaySeconds | int | `5` |  |
| oAuthSidecar.startupProbe.periodSeconds | int | `30` |  |
| oAuthSidecar.startupProbe.successThreshold | int | `1` |  |
| oAuthSidecar.startupProbe.timeoutSeconds | int | `5` |  |
| podSecurityContext | object | `{"fsGroup":992,"runAsGroup":992,"runAsNonRoot":true,"runAsUser":992}` | security context at the pod level |
| readinessProbe | object | `{"enabled":true,"spec":{"failureThreshold":1,"initialDelaySeconds":5,"periodSeconds":5,"tcpSocket":{"port":61616},"timeoutSeconds":5}}` | readinessProbe verifies that Artemis can serve messages on addresses so it checks the acceptor ports. We currently only check the main acceptor port on 61616.  If other ports are needed then update to use https://github.com/artemiscloud/activemq-artemis-broker-kubernetes-image/blob/main/modules/activemq-artemis-launch/added/readinessProbe.sh. Backup instances do not accept connections so they will always be unready and needs to be off in HA mode otherwise kubernetes will not create endpoints and artemis will not come up. |
| replicas | int | `1` |  |
| resourceLimitSettings | object | `{"match":"\"#\"","maxConnections":500,"maxQueues":300}` | https://activemq.apache.org/components/artemis/documentation/latest/resource-limits.html#resource-limits |
| resourceLimitSettings.maxConnections | int | `500` | how many connections are allowed by the matched user |
| resourceLimitSettings.maxQueues | int | `300` | how many queues can be created by the matched user |
| resources.limits.memory | string | `"3G"` |  |
| resources.requests.cpu | string | `"100m"` |  |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}` | Artemis container security context |
| settings.authenticationCacheSize | int | `1000` | https://activemq.apache.org/components/artemis/documentation/latest/security.html#tracking-the-validated-user |
| settings.authorizationCacheSize | int | `1000` | https://activemq.apache.org/components/artemis/documentation/latest/security.html#tracking-the-validated-user |
| settings.connectionTTLCheckInterval | int | `1000` | how often (in ms) to check connections for ttl violation. https://activemq.apache.org/components/artemis/documentation/latest/connection-ttl.html#detecting-dead-connections |
| settings.connectionTTLOverride | int | `30000` | if set, this will override how long (in ms) to keep a connection alive without receiving a ping. -1 disables this setting. https://activemq.apache.org/components/artemis/documentation/latest/connection-ttl.html#detecting-dead-connections |
| settings.criticalAnalyzer | bool | `true` | enable or disable the critical analysis. https://activemq.apache.org/components/artemis/documentation/latest/critical-analysis.html#critical-analysis-of-the-broker |
| settings.criticalAnalyzerCheckPeriod | int | `60000` | time used to check the response times. 0.5 * critical-analyzer-timeout. https://activemq.apache.org/components/artemis/documentation/latest/critical-analysis.html#critical-analysis-of-the-broker |
| settings.criticalAnalyzerPolicy | string | `"HALT"` | should the server log, be halted or shutdown upon failures. https://activemq.apache.org/components/artemis/documentation/latest/critical-analysis.html#critical-analysis-of-the-broker |
| settings.criticalAnalyzerTimeout | int | `120000` | timeout used to do the critical analysis. https://activemq.apache.org/components/artemis/documentation/latest/critical-analysis.html#critical-analysis-of-the-broker |
| settings.diskScanPeriod | int | `5000` | The interval where the disk is scanned for percentage usage in ms. https://activemq.apache.org/components/artemis/documentation/latest/paging.html#monitoring-disk |
| settings.globalMaxSize | int | `-1` | The amount in bytes before all addresses are considered full. Defaults to half JVM size. https://activemq.apache.org/components/artemis/documentation/latest/paging.html#global-max-messages |
| settings.journalBufferSize | int | `1485760` | The size of the internal buffer on the journal in KB. https://activemq.apache.org/components/artemis/documentation/latest/persistence.html#configuring-the-message-journal |
| settings.journalBufferTimeout | int | `1500000` | The Flush timeout for the journal buffer. https://activemq.apache.org/components/artemis/documentation/latest/persistence.html#configuring-the-message-journal |
| settings.journalMinFiles | int | `2` | how many journal files to pre-create. https://activemq.apache.org/components/artemis/documentation/latest/persistence.html#configuring-the-message-journal |
| settings.journalPoolFiles | int | `50` | The upper threshold of the journal file pool, -1 means no Limit. The system will create as many files as needed however when reclaiming files it will shrink back to the journal-pool-files. https://activemq.apache.org/components/artemis/documentation/latest/persistence.html#configuring-the-message-journal |
| settings.maxDiskUsage | int | `95` | The max percentage of data we should use from disks. The System will block while the disk is full.  https://activemq.apache.org/components/artemis/documentation/latest/paging.html#max-disk-usage |
| settings.populateValidatedUser | bool | `true` | whether or not to add the name of the validated user to the messages that user sends. https://activemq.apache.org/components/artemis/documentation/latest/security.html#tracking-the-validated-user |
| settings.securityEnabled | bool | `true` | true means that security is enabled. https://activemq.apache.org/components/artemis/documentation/latest/security.html#authentication-authorization |
| settings.securityInvalidationInterval | int | `10000` | how long (in ms) to wait before invalidating the security cache. https://activemq.apache.org/components/artemis/documentation/latest/security.html#authentication-authorization |
| startupProbe | object | `{"enabled":true,"spec":{"failureThreshold":24,"periodSeconds":5,"tcpSocket":{"port":8161}}}` | Wait for management console to be up before considering started for live and backup. requires kubernetes api 1.18+ |
| zookeeper-bitnami.enabled | bool | `false` |  |
| zookeeper-bitnami.zookeeper.nameOverride | string | `"artemis-zookeeper"` |  |
| zookeeper-bitnami.zookeeper.persistence.size | string | `"200M"` |  |
| zookeeper-bitnami.zookeeper.replicaCount | int | `3` |  |
| zookeeper-bitnami.zookeeper.resourcesPreset | string | `"none"` |  |
| zookeeper-bitnami.zookeeper.tls.resourcesPreset | string | `"none"` |  |
| zookeeper-bitnami.zookeeper.volumePermissions.resourcesPreset | string | `"none"` |  |

