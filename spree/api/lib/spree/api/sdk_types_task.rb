# `rake spree:sdk:serializer_types`: writes the response types of a package
# that extends Spree's SDKs from the serializers of the extension or app it
# runs in (see sdk_types.rb). `spree sdk generate` runs it with OUT set to the
# package's output folder; nothing else has to be configured.
#
# An extension gets the task from `spree/testing_support/extension_rake`, and
# runs it against its test app (`bundle exec rake test_app` first). A Spree
# application gets it from spree_api's own tasks, against itself.
require 'rake'

module Spree
  module Api
    class SdkTypesTask
      include Rake::DSL

      # @param engine [String, nil] the engine class; by default the engine,
      #   or the application, whose root is the current folder
      # @param out [String, nil] where to write; by default `ENV['OUT']`
      # @param dummy [String] an extension's test app environment file
      def initialize(engine: nil, out: nil, dummy: 'spec/dummy/config/environment.rb')
        return if Rake::Task.task_defined?('spree:sdk:serializer_types')

        namespace :spree do
          namespace :sdk do
            desc "Generate the SDK response types from this extension's or app's serializers (OUT=folder)"
            task :serializer_types do
              target = out || ENV['OUT']
              abort 'Pass OUT, the folder to write the types to, or run `spree sdk generate`.' if target.to_s.empty?

              boot(dummy)
              require 'spree/api/sdk_types'

              owner = engine ? engine.constantize : self.class.owner_here
              abort "No engine or application has its root in #{Dir.pwd}" unless owner

              apis = Spree::Api::SdkTypes.generate!(engine: owner, out: File.expand_path(target))
              puts apis.any? ? "Wrote the #{apis.join(', ')} response types to #{target}" : "No serializers under #{owner.root}/app/serializers"
            end
          end
        end
      end

      # @return [Class<Rails::Engine>, Rails::Application, nil] the engine or
      #   application whose root is the current folder
      def self.owner_here
        here = File.expand_path(Dir.pwd)
        Rails::Engine.subclasses.find { |engine| File.expand_path(engine.root.to_s) == here } ||
          (Rails.application if File.expand_path(Rails.application.root.to_s) == here)
      end

      private

      # Typelizer records the serializers' `typelize` declarations only when
      # TYPELIZER is on as the app boots, so it is set first.
      def boot(dummy)
        ENV['TYPELIZER'] = 'true'
        if File.exist?(dummy)
          ENV['RAILS_ENV'] ||= 'test'
          require File.expand_path(dummy)
        elsif Rake::Task.task_defined?(:environment)
          Rake::Task[:environment].invoke
        else
          abort 'Build the test app first: bundle exec rake test_app'
        end
      end
    end
  end
end
