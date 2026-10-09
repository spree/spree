module Spree
  module Api
    # Generates every SDK's TypeScript types from the serializers, the email
    # template types included. Runs inside spree_emails' test app, the one
    # place where the API's and the email serializers are all loaded: running
    # it with any serializer missing would delete that serializer's types.
    module TypelizerGeneration
      # @param serializer_dirs [Array<String, Pathname>] directories to load before generating
      def self.call(serializer_dirs)
        serializer_dirs.each { |dir| Rails.autoloaders.main.eager_load_dir(dir.to_s) }

        require 'typelizer/generator'
        Typelizer::Generator.call(force: true)

        # `interface` rather than `type`, so SDK consumers can extend generated
        # types through declaration merging.
        api_root = Spree::Api::Engine.root
        [api_root.join('../../packages/sdk/src/types/generated'), api_root.join('../../packages/admin-sdk/src/types/generated'),
         api_root.join('../../packages/admin-sdk/src/types/generated/emails')].each do |dir|
          Dir[File.join(dir, '*.ts')].each do |file|
            next if File.basename(file) == 'index.ts'

            content = File.read(file)
            updated = content.gsub(/^type (\w+) = \{/, 'interface \1 {')
            File.write(file, updated) if updated != content
          end
        end

        # The typed webhook events in @spree/sdk, from the event catalog.
        require Spree::Api::Engine.root.join('lib/spree/api/webhook_event_types').to_s
        Spree::Api::WebhookEventTypes.new.write!(api_root.join('../..'))

        # Each configurable family's preferences, typed by `type`, in the Admin and Seller SDKs.
        require Spree::Api::Engine.root.join('lib/spree/api/preference_types').to_s
        Spree::Api::PreferenceTypes.new.write!(api_root.join('../..'))
      end
    end
  end
end
