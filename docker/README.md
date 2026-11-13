# Spree Docker images

This directory defines `ghcr.io/spree/spree-base`, the image every Spree project builds its own image on. The design and its decisions are in [`docs/plans/6.1-spree-base-image.md`](../docs/plans/6.1-spree-base-image.md); the user-facing guide is [`docs/developer/deployment/docker.mdx`](../docs/developer/deployment/docker.mdx).

| Path | What it is |
| --- | --- |
| `base/Dockerfile` | The base image: a `runtime` target and a `build` target |
| `base/bin/spree-entrypoint` | The entrypoint of both |
| `base/bin/spree-image-build` | The build script shipped in the build variant |
| `base/lines.json` | The Spree lines whose base image is rebuilt, with the Ruby and Node version and the git refs each is built from |
| `project/Dockerfile` | The Dockerfile a project uses. spree-starter ships a copy, and `spree upgrade` writes it |

## The contract

A project's Dockerfile, and a later Spree major, rely on these and nothing else. Do not add to the list without updating the plan.

- The built app lives in `/rails`, the dashboard in `/rails/dashboard`, the seller panel in `/rails/seller-dashboard`, and gems in `/usr/local/bundle`.
- `spree-image-build gems` and `spree-image-build app <context>` build a project.
- The app listens on port 3000 and answers `GET /up`.
- The entrypoint prepares the database before the Rails server starts in production, and installs missing gems before any command outside production.
- The app runs as the `rails` user, uid 1000.

## Building locally

```bash
docker build docker/base --target runtime --build-arg SPREE_LINE=6.1 -t ghcr.io/spree/spree-base:6.1
docker build docker/base --target build --build-arg SPREE_LINE=6.1 -t ghcr.io/spree/spree-base:6.1-build
```

A project then builds against the local images with `docker build . -f server/Dockerfile`.

## Publishing

`.github/workflows/base-image.yml` builds every line in `base/lines.json` weekly and when this directory changes. For each line and architecture it builds both variants, builds a stock Spree image from `spree/spree-starter` on top, and boots it. Only when every build passes does it move the line tag (`6.1`, `6.1-build`), add dated tags (`6.1-20261116`, `6.1-20261116-build`) and attach a build provenance attestation. A pull request runs the same builds and publishes nothing.

The stock image `ghcr.io/spree/spree` is published by `spree/spree-starter`, from its copy of `project/Dockerfile`.
