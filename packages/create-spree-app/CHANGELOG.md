# create-spree-app

## 0.2.2

### Patch Changes

- Replace giget with `git clone --depth 1` for downloading storefront template — fixes EACCES cache permission errors and reduces bundle size by 75%

## 0.2.1

### Patch Changes

- Fix EACCES permission error when downloading storefront template by pre-creating the giget cache directory

## 0.2.0

### Minor Changes

- Add dynamic port detection using get-port — if port 3000 is in use during scaffold, automatically picks the next available port. Add `--port` CLI flag for explicit override. Add `npm run stop` command.

## 0.1.2

### Patch Changes

- Add background worker service to Docker Compose for Solid Queue job processing, rename service from `spree` to `web`/`worker`

## 0.1.1

### Patch Changes

- Fix Docker compose template: use DATABASE_URL for production, set separate database URLs for cache/queue/cable, disable SSL for local development, and load SECRET_KEY_BASE via env_file
