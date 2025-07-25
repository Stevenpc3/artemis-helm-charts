# zookeeper-bitnami

[ Chart version `13.8.3-0` ]

Apache Zookeeper

### Sources:

* <https://github.com/bitnami/charts/tree/main/bitnami/zookeeper>
* <https://artifacthub.io/packages/helm/bitnami/zookeeper>
* <https://zookeeper.apache.org/>

### Updating the charts

Please look for changes to the Bitnami Zookeeper chart at https://github.com/bitnami/charts/commits/main/bitnami/zookeeper

If there are significant or important changes required then also check https://artifacthub.io/packages/helm/bitnami/zookeeper for the matching
release.  Then update the chart to increase the dependencies and the appVersion to reflect the current Zookeeper version used.  Update the changelog to describe the changes.

#### Get more parameters at https://artifacthub.io/packages/helm/bitnami/zookeeper#parameters

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.imageRegistry | string | `""` |  |
| global.security.allowInsecureImages | bool | `true` |  |
| global.storageClass | string | `""` |  |
| zookeeper.image.registry | string | `"cdn.harbor.company.com"` |  |
| zookeeper.image.repository | string | `"ext.hub.docker.com/bitnami/zookeeper"` |  |
| zookeeper.resourcesPreset | string | `"none"` |  |
| zookeeper.tls.resourcesPreset | string | `"none"` |  |
| zookeeper.volumePermissions.image.registry | string | `"cdn.harbor.company.com"` |  |
| zookeeper.volumePermissions.image.repository | string | `"ext.hub.docker.com/zookeeper/os-shell"` |  |
| zookeeper.volumePermissions.resourcesPreset | string | `"none"` |  |

