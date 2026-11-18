---
"@spree/cli": minor
"create-spree-app": patch
---

The CLI works with projects built on the Spree base image, `ghcr.io/spree/spree-base`. Such a project runs the published build image in development, so `spree build` pulls the newer base image where it used to rebuild, and `spree eject` and the database setup no longer expect a `build:` section in the compose file. `spree build --production` builds a Dockerfile on the base image from the project root.

`spree upgrade` offers to move a project onto the base image when it reaches Spree 6.1: it replaces a stock `server/Dockerfile` with a short one on the base, switches the stock `build:` section of the compose files to the build image, and changes `ruby file: '.ruby-version'` in the `Gemfile` to accept any patch of that Ruby minor. A Dockerfile or compose file you have changed is left alone, with a message.

New projects' agent instructions say that Spree images are published only at `ghcr.io/spree`.
