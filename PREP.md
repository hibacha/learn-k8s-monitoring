# Prep for monitoring course

## Dependencies to install before course

### Kuberentes previous course dependencies

Assuming you already participated in other Kubernetes
courses, you should already have the following:

* gcloud SDK
* kubectl
* Docker

## Dependencies new to this course

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

In the cloned repo run `make prep`.  If it succeeds you're ready.
Resolve the missing dependency for any failures.
