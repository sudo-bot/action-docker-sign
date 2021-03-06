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

## Example with docker buildx using manifests

```yml
name: Publish Docker image
on:
  push:
    tags:
       - 'v*'

jobs:
  push_to_registry:
    name: Push Docker image to Docker hub
    runs-on: ubuntu-latest
    strategy:
        fail-fast: false
        max-parallel: 2
        matrix:
            include:
                # All non supported by base image are commented
                # This is an example for base image alpine
                - { platform: "linux/arm64", platform-tag: "arm64" }
                - { platform: "linux/amd64", platform-tag: "amd64" }
                - { platform: "linux/arm/v7", platform-tag: "armv7" }
                - { platform: "linux/arm/v6", platform-tag: "armv6" }
                - { platform: "linux/ppc64le", platform-tag: "ppc64le" }
                #- { platform: "linux/riscv64", platform-tag: "riscv64" }
                - { platform: "linux/s390x", platform-tag: "s390x" }
                - { platform: "linux/386", platform-tag: "386" }
                #- { platform: "linux/mips64le", platform-tag: "mips64le" }
                #- { platform: "linux/mips64", platform-tag: "mips64" }

    steps:
        - name: Check out the repository
          uses: actions/checkout@v2
        - name: Login to DockerHub
          uses: docker/login-action@v1
          with:
            registry: docker.io
            username: ${{ secrets.DOCKER_REPOSITORY_LOGIN }}
            password: ${{ secrets.DOCKER_REPOSITORY_PASSWORD }}
        # https://github.com/docker/setup-qemu-action
        - name: Set up QEMU
          uses: docker/setup-qemu-action@v1
        # https://github.com/docker/setup-buildx-action
        - name: Set up Docker Buildx
          uses: docker/setup-buildx-action@v1
        - name: Build action image
          run: PLATFORM="${{ matrix.platform }}" IMAGE_TAG="docker.io/botsudo/nut-upsd:${{ matrix.platform-tag }}-latest" make docker-build
          env:
            DOCKER_BUILDKIT: 1

        - name: Sign and push docker image
          uses: sudo-bot/action-docker-sign@latest
          with:
            image-ref: "docker.io/botsudo/nut-upsd:${{ matrix.platform-tag }}-latest"
            private-key-id: "${{ secrets.DOCKER_PRIVATE_KEY_ID }}"
            private-key: ${{ secrets.DOCKER_PRIVATE_KEY }}
            private-key-passphrase: ${{ secrets.DOCKER_PRIVATE_KEY_PASSPHRASE }}

  sign-manifest:
    name: Sign the docker hub manifest
    runs-on: ubuntu-latest
    needs: push_to_registry
    steps:
        - uses: actions/setup-go@v2
          with:
            go-version: '^1.12'
        - name: 'Install module'
          run: |
            export GO111MODULE=on
            go get github.com/theupdateframework/notary
            go install -tags pkcs11 github.com/theupdateframework/notary/cmd/notary@latest
            notary --help
        - name: Login to DockerHub
          uses: docker/login-action@v1
          with:
            registry: docker.io
            username: ${{ secrets.DOCKER_REPOSITORY_LOGIN }}
            password: ${{ secrets.DOCKER_REPOSITORY_PASSWORD }}
        - name: Create a manifest
          run: |
            DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create docker.io/botsudo/nut-upsd:latest \
                docker.io/botsudo/nut-upsd:arm64-latest \
                docker.io/botsudo/nut-upsd:amd64-latest \
                docker.io/botsudo/nut-upsd:armv7-latest \
                docker.io/botsudo/nut-upsd:armv6-latest \
                docker.io/botsudo/nut-upsd:ppc64le-latest \
                docker.io/botsudo/nut-upsd:s390x-latest \
                docker.io/botsudo/nut-upsd:386-latest \
                --amend

        - name: Sign and push the manifest
          uses: sudo-bot/action-docker-sign@latest
          with:
            image-ref: "docker.io/botsudo/nut-upsd:latest"
            # Please use the repository key for the manufest or pull will not work
            private-key-id: "${{ secrets.DOCKER_PRIVATE_KEY_ID }}"
            private-key: ${{ secrets.DOCKER_PRIVATE_KEY }}
            private-key-passphrase: ${{ secrets.DOCKER_PRIVATE_KEY_PASSPHRASE }}
            sign-manifest: true
            notary-auth: "${{ secrets.DOCKER_REPOSITORY_LOGIN }}:${{ secrets.DOCKER_REPOSITORY_PASSWORD }}"

```

## Some errors you may run into

- I had filled the repository key and key Id in the ENV variables and that did throw `failed to sign docker.io/botsudo/capistrano:latest: no valid signing keys for delegation roles` to me.
- Then I updated the contents to use the user key contents but forgot to update the key Id and that did throw `failed to sign docker.io/botsudo/capistrano:latest: The targets metadata is invalid: tuf: data has no signatures` to me.
- When using the user key Id and key contents it did work fine.

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
notary delegation list docker.io/botsudo/capistrano -s https://notary.docker.io
docker trust signer add --key ./key-name-or-user-name.pub key-name-or-user-name docker.io/botsudo/capistrano
# To remove it (if you did not use the right key)
docker trust signer remove williamdes docker.io/botsudo/capistrano
notary delegation list docker.io/botsudo/capistrano -s https://notary.docker.io
# Using --local or not may change the results of what you are trying to do
docker trust sign --local docker.io/botsudo/capistrano:latest
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

### Push a manifest

Purge is needed to be sure next time you create the manifest it updates the images.
Ref: [comment](https://github.com/docker/cli/issues/954#issuecomment-586722447)

```sh
DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push docker.io/botsudo/nut-upsd:latest --purge
```

### Sign it

My testing show you need to sign **manifests** with the repository key otherwise pull will not work.
So do not use `-r targets/sudo-bot`

If you do not use a manifest you can use the same key as the one to sign the image, anyway you should not even be reading this because the image is already signed at this point.

#### Fetch and check the values

Set the repo to work on

```sh
REPO="botsudo/nut-upsd"
```

Get a token (per $REPO)

```sh
AUTH_BASIC_FROM_DOCKER_CREDS_IN_BASE64="$(cat ~/.docker/config.json | jq -r '.auths."https://index.docker.io/v1/".auth')"
DT="$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${REPO}:pull" -H "Authorization: Basic ${AUTH_BASIC_FROM_DOCKER_CREDS_IN_BASE64}" | jq -r '.token')"
# This is usefull if you will do commands using the "notary" program
export NOTARY_AUTH="${AUTH_BASIC_FROM_DOCKER_CREDS_IN_BASE64}"
```

Fetch the manifest bytes count (Gives: `946` bytes for this example)

```sh
BYTES_SIZE="$(curl -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://registry-1.docker.io/v2/$REPO/manifests/latest -H "Authorization: Bearer $DT" -XGET | wc -c)"
```

Fetch the manifest sha-256 sum (Gives: `19ab62db03bf648a8a884ddcdefca9b9e8cdbd97613e66dc454466c2d4b3bc3b` for this example)

```sh
SHA="$(curl -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' https://registry-1.docker.io/v2/$REPO/manifests/latest -H "Authorization: Bearer $DT" -XGET | sha256sum)"
```

Source: [for the skopeo command](https://www.unboundtech.com/docs/UKC/UKC_Code_Signing_IG/HTML/Content/Products/UKC-EKM/UKC_Code_Signing_IG/Notary/notary_overview.htm)

The `BYTES_SIZE` bytes length can be fetched using [skopeo](https://github.com/containers/skopeo): `skopeo inspect --raw docker://docker.io/$REPO | wc -c` **and should match `${BYTES_SIZE}`**.

And the hash from `skopeo inspect --raw docker://docker.io/$REPO | sha256sum` **should match `${MANIFEST_SHA_FROM_ABOVE_COMMAND}`**

Last method to get the values: `DOCKER_CLI_EXPERIMENTAL=enabled docker manifest inspect docker.io/$REPO -v | jq '.Descriptor'`, `digest` and `size` should be coherent with `${MANIFEST_SHA_FROM_ABOVE_COMMAND}` and `${BYTES_SIZE}`.

#### Add the hash to notary

```sh
notary addhash -p docker.io/$REPO latest ${BYTES_SIZE} --sha256 ${MANIFEST_SHA_FROM_ABOVE_COMMAND}
```

You can remove it if you need: `notary remove docker.io/$REPO latest -r targets/williamdes --publish` (`targets/williamdes` can be removed depending on what key signed the value to remove).

#### Some usefull notes

Using manifests always did give `946` for `${BYTES_SIZE}` for some reason, but not on single signed images.

**A very important note:** `notary list docker.io/botsudo/nut-upsd` can list the bad last signed value, like it was hiding another value behind it. This is why I use `notary remove` when I can not get the same value as the one the signing CI printed out at the end of the process.

**Example:** I had signed an image with my local key, and then I released a version that was signed by the CI key. When I listed using `notary list` the signed value by the CI was not showing. After removing my signature of the previous value it worked fine.

This [website](https://containers.gitbook.io/build-containers-the-hard-way/#registry-format-oci-image-manifest) is helpfull to know more about how manifests are built.

### See the results

Check the SHAs !!

```sh
docker trust inspect docker.io/botsudo/nut-upsd --pretty
notary list docker.io/botsudo/nut-upsd
docker pull docker.io/botsudo/nut-upsd:latest --disable-content-trust=false
```

## Exporting a key

### In the "Notary format"

Ref: https://github.com/theupdateframework/notary/issues/1363
Ref: https://github.com/docker/cli/issues/1095#issuecomment-423707423

```sh
notary key export -d ~/.docker/trust --key 46afe37834b3f7f7f76f5f9cfb77d7a8a3383353581cdf74236dcf43df0260e4
```
