# action-docker-sign

Sign your Docker images using [Docker Content Trust (DCT)](https://docs.docker.com/engine/security/trust/) !

## Complete example

You can forge the key following [this manual](https://docs.docker.com/engine/security/trust/#signing-images-with-docker-content-trust)

/!\ Be sure to save in a safe place your root key

/!\ Do not use the repository or root key here, use a created delegated key

```yml
name: Publish Docker image on tag push
on:
  push:
    tags:
       # Only the tag named latest
       - 'latest'

jobs:
  push_to_registry:
    name: Push Docker image to Docker hub
    runs-on: ubuntu-latest
    steps:
        - name: Check out the repository
          uses: actions/checkout@v2
        - name: Login to DockerHub
          uses: docker/login-action@v1
          with:
            registry: docker.io
            username: ${{ secrets.DOCKER_REPOSITORY_LOGIN }}
            password: ${{ secrets.DOCKER_REPOSITORY_PASSWORD }}
        - name: Build action image
          # Use any good build command and be sure to tag the image correctly
          run: IMAGE_TAG="docker.io/botsudo/action-docker-compose:latest" make docker-build

        - name: Sign and push docker image
          uses: sudo-bot/action-docker-sign@latest
          with:
            image-ref: "docker.io/botsudo/action-docker-compose:latest"
            # Example: 51f9a39f3db4ddaaf9174fca69f41fb01a04a4dfb5125ef115feecb93d19efa6
            private-key-id: "${{ secrets.DOCKER_PRIVATE_KEY_ID }}"
            # The contents from: ~/.docker/trust/private/51f9a39f3db4ddaaf9174fca69f41fb01a04a4dfb5125ef115feecb93d19efa6.key)
            private-key: ${{ secrets.DOCKER_PRIVATE_KEY }}
            # Example: myPassw0rdChangeMeReplaceMe
            private-key-passphrase: ${{ secrets.DOCKER_PRIVATE_KEY_PASSPHRASE }}
```

## Inspect trust

(be sure to check that the SHA matches, it will use the latest signed image if no signature has been done)

```sh
docker trust inspect docker.io/botsudo/action-docker-compose:latest --pretty
```

### Example inspect output

```text
Signatures for docker.io/botsudo/action-docker-compose:latest

SIGNED TAG          DIGEST                                                             SIGNERS
latest              8729542ca14dd459473e15719924d545809ce86a1b8e83c714e7108283841d13   sudo-bot

List of signers and their keys for docker.io/botsudo/action-docker-compose:latest

SIGNER              KEYS
sudo-bot            46afe37834b3
williamdes          51f9a39f3db4

Administrative keys for docker.io/botsudo/action-docker-compose:latest

  Repository Key:	fd6e4192798bf44c9e38bc4977d32701b5f78d3b27b1d3552e466f1f7460b2ed
  Root Key:	40222665dc8b8f91ae7a6fe5b0ec806ff3de8849374175b0334225235347525a
```

## Check that it works

(be sure to check that the SHA matches)

```sh
docker pull docker.io/botsudo/action-docker-compose:latest --disable-content-trust=false
```

### Example pull output

```text
Pull (1 of 1): botsudo/action-docker-compose:latest@sha256:8729542ca14dd459473e15719924d545809ce86a1b8e83c714e7108283841d13
sha256:8729542ca14dd459473e15719924d545809ce86a1b8e83c714e7108283841d13: Pulling from botsudo/action-docker-compose
Digest: sha256:8729542ca14dd459473e15719924d545809ce86a1b8e83c714e7108283841d13
Status: Image is up to date for botsudo/action-docker-compose@sha256:8729542ca14dd459473e15719924d545809ce86a1b8e83c714e7108283841d13
Tagging botsudo/action-docker-compose@sha256:8729542ca14dd459473e15719924d545809ce86a1b8e83c714e7108283841d13 as botsudo/action-docker-compose:latest
docker.io/botsudo/action-docker-compose:latest
```

## Some usefull commands

```sh
notary delegation list docker.io/botsudo/action-scrutinizer -s https://notary.docker.io
docker trust signer add --key williamdes.pub williamdes docker.io/botsudo/action-scrutinizer
docker trust signer add --key williamdes.pub williamdes docker.io/botsudo/action-scrutinizer:latest
```

## Sign multi platform manifests

A solution for: https://github.com/docker/buildx/issues/313 and https://github.com/docker/cli/issues/392

### Make a manifest

Use `--amend` to update it.

```sh
DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create docker.io/botsudo/nut-upsd:latest \
    docker.io/botsudo/nut-upsd:arm64-latest \
    docker.io/botsudo/nut-upsd:amd64-latest \
    docker.io/botsudo/nut-upsd:armv7-latest \
    docker.io/botsudo/nut-upsd:armv6-latest \
    docker.io/botsudo/nut-upsd:ppc64le-latest
```

### Sign it

```sh
notary addhash -p docker.io/botsudo/nut-upsd latest 946 --sha256 ${MANIFEST_SHA_FROM_ABOVE_COMMAND} -r targets/sudo-bot
```

### See the results

Check the SHAs !!

```sh
docker trust inspect docker.io/botsudo/nut-upsd --pretty
notary list docker.io/botsudo/nut-upsd
docker pull docker.io/botsudo/nut-upsd:latest --disable-content-trust=false
```
