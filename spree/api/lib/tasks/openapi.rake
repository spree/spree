# `spree task openapi:generate` (`bin/rails spree:openapi:generate`) in a Spree
# application: writes openapi/admin.yaml from the app's own rswag specs, so the
# admin endpoints it adds are documented, and each documented action is an
# agent tool. Extensions get the same task from extension_rake.
load File.expand_path('../spree/api/testing_support/openapi_tasks.rb', __dir__)
