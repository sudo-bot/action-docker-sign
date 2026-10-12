# action-docker-sign

> ## ⚠️ Retired
>
> This action signed Docker images with **Docker Content Trust (DCT)**, backed by
> the Notary v1 service at `notary.docker.io`. DCT and Notary v1 are being fully
> retired, with a complete shutdown on **2026-12-08**, so the action has been
> removed and workflows pinned to it will stop working.
>
> Read **[Docker Content Trust: Retirement and Migration Guidance](https://www.docker.com/blog/docker-content-trust-retirement-and-migration-guidance/)**
> for the full story and the migration detail.

## What to do instead

- **Unblock pulls** — unset `DOCKER_CONTENT_TRUST` everywhere it is set.
- **Pin by digest** — `docker pull busybox@sha256:...`, immutable and reproducible.
- **Sign images** — [Sigstore/Cosign](https://docs.sigstore.dev/quickstart/quickstart-cosign/) (OIDC identity) or [Notation](https://notaryproject.dev/docs/quickstart/) (PKI).
- **Enforce signatures** — [Kyverno](https://kyverno.io/) for Cosign, Ratify + Gatekeeper for Notation.
- **Or replace the base image** — [Docker Hardened Images](https://docs.docker.com/dhi/) ship signed, with provenance attestations and SBOMs.

Docker cannot re-sign on your behalf: if you published images with DCT, re-sign them with Cosign or Notation yourself.

## Special thanks

Thank you to all the users that contacted me about this and where happy that I documented the commands.
I am glad this is gone, as it was not very easy to use nor to understand.
