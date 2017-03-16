# Prep for monitoring course

## Dependencies to install before course

### Kuberentes 101 dependencies

Assuming you already participated in 101, you should already have
the following:

* gcloud SDK
* kubectl
* Docker

### Install envtpl

All: `pip install envtpl`

Note if `pip` is not available on your Mac, you probably need to upgrade
your python package. `brew` makes this simple: `brew install python`.

`pip` should now be available.

### Install siege

OSX: `brew install siege`
Ubuntu: sudo apt-get install siege

### Clone the repo

clone it.

## Validate it all.

For validation let's point ourselves to the training-sandbox:

```bash
$ gcloud container clusters get-credentials \
  --project meetup-dev \
  --zone us-east1-b \
  training-sandbox
```

In the cloned repo run `make prep`.  If it succeeds you're ready.
Resolve the missing dependency for any failures.
