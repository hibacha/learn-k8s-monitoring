# Kubernetes 201

## Prepare for this course by following these steps: [PREP.md](PREP.md)

## The Concepts

This tutorials introduces two new Kubernetes resources, __ConfigMaps__ and __Secrets__.

Some new `kubectl` commands are introduced as well:

* `kubectl log`
* `kubectl rollout`
* `kubectl exec`

The last step of this tutorial goes over some advanced
steps for deployments in order to provide a __zero
downtime deployment__.

# __Before anything else, start by ensuring that we're pointed at the correct cluster__:

```bash
$ make get-credentials
```

## The project

This project is setup as one of our "BLT" projects.  That means it
implements our common Makefile contract.  You'll find targets like
`package`, `publish`, and `deploy`.

To see all the documented targets, `make help` is also available.

Also included is a simple component test to verify
that the artifact works for the general case.

For this specific project, the namespacing of the Kubernetes resources
is templated and will filled with your username.

![Diagram of the project]
(https://docs.google.com/drawings/d/1PGwzTalicP_2t-lmjyK9p0eCgFl1OHOaqFMmWAqAxbI/pub?w=763&h=529)

### Deploy the project

Using `publish` we can build our artifact push it
to the registry for.

```bash
$ make publish
```

And finally deploy our new artifact to the production cluster.

```bash
$ make deploy
```

Provided a convenience method that will set your namespace
for all of your `kubectl` commands.

```bash
$ make set-ns
```

### How is our service?

Using our get commands let's lookup our SVC and possibly watch
until the load balancer had finished provisioning.

```bash
$ kubectl get svc -w
```

And make a request to the service.

## ConfigMaps

Our application currently isn't configured the way we want it to be.
In loading up we saw that our north star metric clearly wasn't
the right metric.  Since this information is loaded from a file
in our application, we can use a Kubernetes __ConfigMap__ to load a
different version of that file into our container.

Configmaps are a resource that contains key-value pairs of
configuration data.  They are scoped to the namespace so only
accessibly by pods on the namespace of the configmap.  They can even
be created directly from a properties file.

More on [ConfigMaps - https://kubernetes.io/docs/user-guide/configmap/](https://kubernetes.io/docs/user-guide/configmap/)

Our resulting file system in the container should look like the following:

```bash
/usr/src/app/     # Working dir.
  |- index.js     # From Docker image.
  |- package.json # From Docker image.
  `- config.yaml  # From cluster.
```

![Diagram of configmap layer]
(https://docs.google.com/drawings/d/1CLLmtG58nLpsjHivmTa2uFRhlwFd1yLT3HBjaUVirg8/pub?w=763&h=529)

### Add ConfigMap to deployment

A config is available to us in the
infra folder: `infra/webserver-cm.yaml`

With our file created, let's add it to our `deploy` target and deploy again.

### Mounting the ConfigMap

In the repository, I've included a ConfigMap already to use.
The ConfigMap is also already apart of the deployment, you may have
seen it get created earlier.

So with the ConfigMap existing, now let's connect it to our deployment.
Add the following to the deployment template spec.

```yaml
volumes:
- name: webserver-config
  configMap:
    name: webserver
```

Add the following to our container:

```yaml
volumeMounts:
- name: webserver-config
  mountPath: /usr/src/app/config.yaml
  subPath: config.yaml
```

### It's broken!! Now how to we do stuff?!??

Looking at the pods, our pod should now be in error
and possibly in a crash backoff loop.

```bash
$ kubectl get pod
```

#### But first, rollback

```bash
$ kubectl rollout status deployment/webserver
$ kubectl rollout history deployment/webserver
```

Rollback the deployment.

```bash
$ kubectl rollout undo deployment/webserver
$ # or
$ kubectl rollout undo deployment/webserver --to-revision {REV}
```

### What's really going on

Since we weren't able to grab the logs we can always head over
to Logging on the Google Cloud Console to see the whole story.

[Logging - https://console.cloud.google.com/logs/viewer?project=meetup-dev](https://console.cloud.google.com/logs/viewer?project=meetup-dev)

There we can filter by the cluster and namespace to view the
logs we want.

### But still broken

Our deployment pods are running but when loading our service
now we're receiving a 500.  Looking at the application, with
a new configuration we have new expectations.  In this case
a secret token needs to be provided.

## Secrets

Secret is a Kubernetes resources that holds sensitive information.
Similar to configmaps they're also scoped to their namespace and
can be injected as volumes or environment variables.
Secrets are also never written to disk so you don't have to worry
about your secrets laying around cluster nodes.

More on [Secrets - https://kubernetes.io/docs/user-guide/secrets/](https://kubernetes.io/docs/user-guide/secrets/)

### Creating a secret



In the repo is a template in `infra/webserver-secret.yaml` and a convenience
method `secrete-template` in the `Makefile`.

Using something like the following, we can generated that template:

```bash
$ # echo -n so no new line is on the end of the echo
$ TOKEN_BASE64=$(echo -n "applesareorange" | base64) \
  make secret-config
```

Now with this generated template, let's pipe it to kubectl to create
the secret.

```bash
$ # echo -n so no new line is on the end of the echo
$ TOKEN_BASE64=$(echo -n "applesareorange" | base64) \
  make secret-config | kubectl apply -f -
```

#### Adding the secret to deployment

Assuming we were successful in adding our secret.  We can now inject the
secret into our deployment.  This time we'll go the environment variable
route instead of the volume mount.

Take a look at the detail about container env vars:

```bash
$ kubectl explain deployment.spec.template.spec.containers.env
$ kubectl explain deployment.spec.template.spec.containers.env.valueFrom
$ kubectl explain deployment.spec.template.spec.containers.env.valueFrom.secretKeyRef
```
So we can configure it in the container with valueFrom using a secretKeyRef.

```yaml
env:
- name: TOKEN
  valueFrom:
    secretKeyRef:
      name: webserver
      key: token
```

## Zero down time deployment

Our service is in working order but all is not well.  Let's take a look at
now we handle deployments.

Replace your svc ip in the following command and run it.

```bash
$ make deploy && siege -t 15S "http://{SVC_IP}/"
```

The output shows us that our deployment isn't zero downtime.  We're losing
a lot of connections on the rolling.

### Observing the container rollout

Let's do that one more time, but this time in another terminal, let's
follow the pod statuses with the `-w` flag.

```bash
$ kubectl get pods -w
```

You'll notice that the old pod is terminated even before our
new pod is up.

#### The problem: `maxUnavailable`

This is due to the rolling update strategy.  Currently this project is
at 1 replica.  But in looking at `maxUnavailable`, the default value is 1.
So in short, our deployment of 1 replica thinks it's okay for 1 replica
to not be available.

```bash
$ kubectl explain deployment.spec.strategy.rollingUpdate.maxUnavailable
```

#### The fix

We have two solutions here, first and most recommended is to just use
more replicas.  With say replicas at 3 and `maxUnavailable` at the default,
we'd always have at least 2 replicas available.

But in this example we want to keep one to one replica for simplicity.
So setting `maxUnavailable` to 0 in our deployment will force the new
pod to come up first.

Let's try running our connection test again while again following the
pod statuses.

Still failing connections, but this time our pods ordered correctly.
As in the new pod come up first before terminating the old one.

#### The problem: `readiness`

Now if you noticed there's a sleep in the startup of this node application.
That's to pretend it's Java ;-).  So the problem we're experiencing is
our Kubernetes service is routing traffic to the new pod before it is ready
to receive traffic.

#### The fix

This is where our `readinessProbe` comes in handy.  Eyeing the docs you'll
notice that http endpoint option is available.

```bash
$ kubectl explain deployment.spec.template.spec.containers.readinessProbe
```

Utilizing some of the details and the existing endpoint in the app,
we can set the readiness probe to not mark the container as fully ready
until the endpoint starts responding.

A final run of our connection test should now show us at 100% success.
You'll also notice when watching the pod status, that this time we enter
state where 0/1 containers is ready for some time.

#### OR IS IT?!?

This works well for this example but something to keep in mind is HTTP
keep-alive and ensuring receive errors do not happen for those connections
when we terminate a pod.  Investigate preStop hooks and terminating the
keep-alive by an upstream proxy for more seamless alive connections.

## Extra Cred

### Using Kubectl exec

We can use `kubectl exec`, similar to `docker exec` to run a command with
interactive terminal on the pod.  In this case the pod is only one
container so it defaults to that container.

```bash
$ kubectl exec -ti {POD} sh
/usr/src/app # ls -l
total 16
-rw-r--r--    1 root     root            32 Jan 19 17:52 config.yaml
-rw-r--r--    1 root     root          1016 Jan 19 16:31 index.js
drwxr-xr-x    8 root     root          4096 Jan 19 17:03 node_modules
-rw-r--r--    3 root     root           133 Jan 18 16:23 package.json
```

### Using GCloud Compute SSH to access container

An alternative way we could jump into this pod is via Docker.

Let's retrieve the node (or instance) this container is running on
via the wide pod output.

```bash
$ kubectl get pods -o wide
```

Now the next step will force you to setup a passphrase for your ssh keys
if you haven't already.  Your SSH keys for Google Cloud will be managed
by them so nothing fancy you have to do.

Let's jump into the node.

```bash
$ gcloud compute ssh {NODE} --project meetup-dev
```

Here we can do the typical Docker commands we all know and love.
