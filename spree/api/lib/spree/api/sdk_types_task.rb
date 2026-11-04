# `rake spree:sdk:serializer_types` for an extension: boots its test app and
# writes the response types of a package that extends Spree's SDKs from the
# extension's serializers (see sdk_types.rb). In the extension's Rakefile:
#
#   require 'spree/api/sdk_types_task'
#   Spree::Api::SdkTypesTask.new(engine: 'MyExtension::Engine', out: '../my-extension-sdk/src/types')
#
# `out` is relative to the engine's root, and the engine is named as a string
# because it loads with the test app. Build the test app first
# (`bundle exec rake test_app`).
require 'rake'

module Spree
  module Api
    class SdkTypesTask
      include Rake::DSL

      # @param engine [String] the extension's engine class
      # @param out [String] where to write the types, relative to the engine's root
      # @param dummy [String] the test app's environment file
      def initialize(engine:, out:, dummy: 'spec/dummy/config/environment.rb')
        namespace :spree do
          namespace :sdk do
            desc "Generate the SDK response types from this extension's serializers"
            task :serializer_types do
              environment = File.expand_path(dummy)
              abort 'Build the test app first: bundle exec rake test_app' unless File.exist?(environment)

              ENV['RAILS_ENV'] ||= 'test'
              # Spree's initializer turns Typelizer off unless this is set.
              ENV['ENABLE_TYPELIZER'] = '1'
              require environment
              require 'spree/api/sdk_types'

              apis = Spree::Api::SdkTypes.generate!(engine: engine.constantize, out: out)
              puts apis.any? ? "Wrote the #{apis.join(', ')} types to #{out}" : "No serializers found under #{engine}'s app/serializers"
            end
          end
        end
      end
    end
  end
end
