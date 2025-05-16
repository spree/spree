#!/bin/sh

set -eux

bundle update
bundler-audit update
for dir in . api core storefront admin emails; do
  (cd "$dir" && bundle update && bundler-audit check)
done
