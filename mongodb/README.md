# Quick Start Guide

This guide covers how to use the MongoDB CE Operator to satisfy the MongoDB prerequisite for Maximo Application Suite (MAS) v8.4. The guide only covers the case of installing the MongoDB CE Operator into an OpenShift Container Platform (OCP) cluster. 

## 1. How is MongoDB used in Maximo Application Suite

Multiple databases are created in Mongo, but both the core MAS runtimes and the IoT tool (if deployed):

| Database                            | Notes                      |
| ----------------------------------- | -------------------------- |
| mas_{instanceid}_core               | Primary datastore for MAS  |
| iot_{instanceid}_cs_activity_db     | Used by IoT                |
| iot_{instanceid}_d_actions          | Used by IoT                |
| iot_{instanceid}_d_core             | Used by IoT                |
| iot_{instanceid}_d_dashboard        | Used by IoT                |
| iot_{instanceid}_d_deviceregistry   | Used by IoT                |
| iot_{instanceid}_d_dmserver         | Used by IoT                |
| iot_{instanceid}_d_dsc              | Used by IoT                |
| iot_{instanceid}_d_infomgmt         | Used by IoT                |
| iot_{instanceid}_d_provision_s2s    | Used by IoT                |
| iot_{instanceid}_d_riskmgmtsecurity | Used by IoT                |
| iot_{instanceid}_organizations      | Used by IoT                |


# Supported Versions

The following MongoDB version is supported:
- `4.2.X`

# default storage class pre-requisite
**You need a configured NFS server already running**
```
cd /usr/local/bin
wget https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/helm-linux-amd64 -O helm

helm repo add stable https://charts.helm.sh/stable

helm repo list
NAME    URL
stable  https://charts.helm.sh/stable

oc new-project nfs-storage-provider --display-name='NFS Dynamic Storage Provider'
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:nfs-storage-provider:nfsprovider-nfs-client-provisioner
helm install nfsprovider stable/nfs-client-provisioner -n nfs-storage-provider --set nfs.server=x.x.x.x --set nfs.path=/xxx
```

to set the as the default storage class:
```
oc patch storageclass nfs-client -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
```

# One-liner alternative
```
oc new-project <project-name>
oc apply -f https://raw.githubusercontent.com/mikelo/iot-docs/master/mongodb/allinone.yaml
```
**This method has neither been test with MAS nor with CP4D yet**

# Installing the Official MongoDB CE Operator

**Important!!!! Maximo Application Suite (MAS) v8.4 does not support authentication via `SCRAM-SHA-256`. The official MongoDB CE Operator only configures `SCRAM-SHA-256` authentication. There is a [work around](#Work-Around-to-Enable-SCRAM-SHA-1-Authentication) that must be followed until MAS updates the version of the MongoDB Java driver being used. Please be sure to follow the steps for the [work around](#Work-Around-to-Enable-SCRAM-SHA-1-Authentication) after installing the MongoDB CE Operator.**

This is a guide to assist with installing and configuring the Official MongoDB Community Kubernetes Operator into OpenShift. The primary objective is to setup MongoDB Community Edition (CE) so it can be used to satisfy the MongoDB prerequisite of Maximo Application Suite (MAS)

The installation and configuration was adapted from the official [MongoDB Community Kubernetes Operator](https://github.com/mongodb/mongodb-kubernetes-operator). You are encouraged to review the applicable documentation provided with the official [MongoDB Community Kubernetes Operator](https://github.com/mongodb/mongodb-kubernetes-operator) 

At the time of this writing v0.6.0 of the MongoDB Community Kubernetes Operator is the latest release.

## Getting Started

Installation of the MongoDB CE operator using this repository has been tested with MongoDB 4.2.6 and OpenShift Container Platform (OCP) v4.6. By default the installation script [install-mongo-ce.sh](install-mongo-ce.sh) will create a three node replica set in the project namespace mongo.

To get started follow these steps:

- Clone the repository https://github.com/mikelo/iot-docs The location to where you have cloned this repository will be referred to as $IOT_DOCS_ROOT. 

Maximo Application Suite v8.4 supports only secure connections to MongoDB. As a convenience the script [generateSelfSignedCert.sh](certs/generateSelfSignedCert.sh) can be used to generate the required server certificate and key. Simply invoke [generateSelfSignedCert.sh](certs/generateSelfSignedCert.sh) from the `$IOT_DOCS_ROOT/mongodb/certs` directory.

To start the installation of the MongoDB CE Operator invoke the `install-mongo-ce.sh` shell script.


```bash

export MONGO_NAMESPACE=mongo

oc login .....

./install-mongo-ce.sh
```

### Validate Installation

Verify the custom resource definition was created:

```bash
oc get crd/mongodbcommunity.mongodbcommunity.mongodb.com
```

Verify that the role, role binding and service account was created.

```bash
oc get role mongodb-kubernetes-operator

oc get rolebinding mongodb-kubernetes-operator

oc get serviceaccount mongodb-kubernetes-operator
```

The install should create a custom resource named `MongoDBCommunity`. From this custom resource you can check the status of the MongoDB replica set by running the following command (example assumes you used the default namespace of `mongo`):

```bash
oc get MongoDBCommunity -n mongo -o yaml

apiVersion: v1
items:
- apiVersion: mongodbcommunity.mongodb.com/v1
  kind: MongoDBCommunity
  metadata:
    annotations:

    ...

  status:
    currentMongoDBMembers: 3
    currentStatefulSetReplicas: 3
    mongoUri: mongodb://mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-1.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-2.mas-mongo-ce-svc.mongo.svc.cluster.local:27017
    phase: Running

    ...
```

## Work Around to Enable SCRAM-SHA-1 Authentication

After the MongoDB CE Operator has deployed and completely restarted scale the operator to zero replicas. This is required because any configuration change made will be undone by the operator. 

```bash
oc edit deployment mongodb-kubernetes-operator
```

Edit the operators deployment and set `replicas` to 0 (zero):

```yaml 
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  creationTimestamp: "2021-05-04T18:47:19Z"
  generation: 1
  name: mongodb-kubernetes-operator
  namespace: mongo
  resourceVersion: "631709603"
  selfLink: /apis/apps/v1/namespaces/mongo/deployments/mongodb-kubernetes-operator
  uid: f801867e-c664-4b63-81dd-418d89a6ab93
spec:
  progressDeadlineSeconds: 600
  replicas: 0
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      name: mongodb-kubernetes-operator

...

```

Then save the deployment and the MongoDB CE Operator should terminate. Once you have scaled the Mongo CE Operator to have no replicas you must edit the secret `mas-mongo-ce-config`. To do this issue the following command:

```bash
oc edit secret mas-mongo-ce-config 
```

The data for the secret is Base64 encoded in the property `cluster-config.json`. Decode the data and update the following two arrays in the `auth` section:

```json
"auth": {

  "autoAuthMechanisms": ["SCRAM-SHA-256", "SCRAM-SHA-1"],
  "autoAuthMechanism": "SCRAM-SHA-256",
  "deploymentAuthMechanisms": ["SCRAM-SHA-256", "SCRAM-SHA-1"],

  }
```

Make sure the arrays `autoAuthMechanisms` and `deploymentAuthMechanisms` contain `SCRAM-SHA-1`. Once you update the JSON you will need to Base64 encode it and set the property `cluster-config.json` to the new encoded value. Then save the secret and do a rolling restart of the stateful set. 

```bash
oc rollout restart statefulset mas-mongo-ce -n ${MONGO_NAMESPACE}
```

See the Configuration Details section of this document on how to validate or view the MongoDB configuration yaml file for each member of the replica set. Make sure that `authenticationMechanisms` is set to `SCRAM-SHA-256,SCRAM-SHA-1`

## Using MongoDB
### Configuration Details

The install will create a custom resource named `MongoDBCommunity` which will create a and configure a three member replica set named `mas-mongo-ce`. The replica set is a StatefulSet. 

```bash
oc get statefulset
NAME           READY   AGE
mas-mongo-ce   3/3     81m
```

Each replica set member is backed by two Persistent Volumes. A data volume (10Gi) and a logs volume (2Gi). The clusters default storage class will be used when create the Persistent Volume Claims. To view the Persistent Volume claim details issue the following command:

```bash
oc get pvc
NAME                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS                  AGE
data-volume-mas-mongo-ce-0   Bound    pvc-a896b3e5-57ef-4940-b941-1ef0c244d602   10Gi       RWO            ocs-storagecluster-ceph-rbd   130m
data-volume-mas-mongo-ce-1   Bound    pvc-11e9a1a7-b298-461e-a9d0-d9d7ee8dd7e4   10Gi       RWO            ocs-storagecluster-ceph-rbd   128m
data-volume-mas-mongo-ce-2   Bound    pvc-1a00b0c5-eafc-4f16-81b8-d5ffec630a93   10Gi       RWO            ocs-storagecluster-ceph-rbd   127m
logs-volume-mas-mongo-ce-0   Bound    pvc-bb3c92fa-1ad7-486d-9daf-7f88dd72ebaf   2Gi        RWO            ocs-storagecluster-ceph-rbd   130m
logs-volume-mas-mongo-ce-1   Bound    pvc-536ec845-cf24-4920-aa51-162c58d789b0   2Gi        RWO            ocs-storagecluster-ceph-rbd   128m
logs-volume-mas-mongo-ce-2   Bound    pvc-09bf2a46-81d6-4093-92af-98ca68f99098   2Gi        RWO            ocs-storagecluster-ceph-rbd   127m
```

The replica set members will mount the data volume at `/data/`. The logs volume is mounted at `/var/log/mongodb-mms-automation/`

Each replica set member will be listening on port 27017 leveraging the service named `mas-mongo-ce-svc`. All pods in the OCP cluster should be able to access the replica set. 

```bash
oc get service 
NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)     AGE
mas-mongo-ce-svc   ClusterIP   None         <none>        27017/TCP   82m
```

Security is enabled for the replica set. The certificate authority (CA) and self-signed certificate from [certs](certs) is used to enable security. The [CA](certs/ca.pem) is placed in a ConfigMap named `mas-mongo-ce-cert-map` and the [server key](certs/server.key) and [certificate](certs/server.crt) are stored in a tls secret named `mas-mongo-ce-cert-secret`.

To view the MongoDB configuration file you can enter one of the replica set containers and view the contents of the file `/data/automation-mongod.conf`

First get the names of the pods that make up the replica set:

```bash
oc get pods
NAME                                           READY   STATUS    RESTARTS   AGE
mas-mongo-ce-0                                 2/2     Running   0          118m
mas-mongo-ce-1                                 2/2     Running   0          119m
mas-mongo-ce-2                                 2/2     Running   0          120m
mongodb-kubernetes-operator-674c554bc4-wh6st   1/1     Running   0          123m
```

Then enter the `mongod` container for one of the replica set member pods:

```bash
oc exec -it mas-mongo-ce-0 --container mongod bash
2000@mas-mongo-ce-0:/$ cat /data/automation-mongod.conf
```

The MongoDB configuration YAML file should look something like:

```yaml
net:
  bindIp: 0.0.0.0
  port: 27017
  tls:
    CAFile: /var/lib/tls/ca/ca.crt
    allowConnectionsWithoutCertificates: true
    allowInvalidCertificates: true
    allowInvalidHostnames: true
    certificateKeyFile: /var/lib/tls/server/436ca8ed50bdefd4684ef536c4c996cfe7f82df91442644c1bc67180e7a7c012.pem
    mode: requireTLS
replication:
  replSetName: mas-mongo-ce
security:
  authorization: enabled
  keyFile: /var/lib/mongodb-mms-automation/authentication/keyfile
setParameter:
  authenticationMechanisms: SCRAM-SHA-256,SCRAM-SHA-1
storage:
  dbPath: /data
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      journalCompressor: snappy
systemLog:
  destination: file
  path: /var/log/mongodb-mms-automation/mongodb.log
```

### Connecting to the Replica Set

As a convenience the custom resource `MongoDBCommunity` can be leveraged to obtain the URI that should be used when connecting to the replica set:

```bash
oc get MongoDBCommunity -n mongo  -o 'jsonpath={..status.mongoUri}'             
mongodb://mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-1.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-2.mas-mongo-ce-svc.mongo.svc.cluster.local:27017
```

Using the URI a connection to the replica set can easily be made from anywhere within the OCP cluster. For example enter container that has access to the `mongo` CLI (for example one of the replica set members) and run the following:

```bash
mongo "mongodb://mas-mongo-ce-0.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-1.mas-mongo-ce-svc.mongo.svc.cluster.local:27017,mas-mongo-ce-2.mas-mongo-ce-svc.mongo.svc.cluster.local:27017/?replicaSet=mas-mongo-ce" --username admin --password <password> --authenticationDatabase admin  --ssl --sslAllowInvalidCertificates 

...

mas-mongo-ce:PRIMARY> 
```

The password can be the one used during the installation. However, it is recommended to further configure [users, and roles](https://docs.mongodb.com/manual/tutorial/manage-users-and-roles/) to fit your needs. And best practice would be to delete the user that was created during the installation process. 

## Clean up

Ensure that you have the executable `oc` and have logged in with appropriate authorization. 

Invoke the [uninstall.sh](uninstall.sh) script
