# `spree task sdk:serializer_types OUT=…` (`bin/rails spree:sdk:serializer_types`)
# in a Spree application: writes the response types of a package that extends
# the SDKs for the app's own endpoints, from the app's serializers. Extensions
# get the same task from extension_rake.
require 'spree/api/sdk_types_task'
Spree::Api::SdkTypesTask.new
