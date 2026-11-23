module Spree
  module Api
    # Generates every SDK's TypeScript types from the serializers, the email
    # template types included. Runs inside spree_emails' test app, the one
    # place where the API's and the email serializers are all loaded: running
    # it with any serializer missing would delete that serializer's types.
    module TypelizerGeneration
      # Serializers that exist only for the Admin API, kept out of the Store
      # SDK. Event serializers stay in: they describe the `data` of the typed
      # webhook events the Store SDK ships.
      STORE_EXCLUDED = %w[Asset CartPromotion OrderPromotion Report TaxCategory].to_set.freeze

      # The store-level types the Seller SDK carries because a seller
      # serializer nests them (see the seller writer in the initializer).
      SELLER_STORE_TYPES = %w[Category CustomField OptionValue Seller].to_set.freeze

      # Typelizer's Alba plugin, taught the custom Alba types (see alba.rb);
      # unmapped typed attributes crash generation.
      #
      # @return [Hash] Typelizer's `plugin_configs`
      def self.plugin_configs
        {
          alba: {
            ts_mapper: Typelizer::SerializerPlugins::Alba::ALBA_TS_MAPPER.merge(
              'iso8601' => { type: :string },
              'string' => { type: :string }
            )
          }
        }
      end

      # `interface` rather than `type`, so SDK consumers can extend generated
      # types through declaration merging.
      #
      # @param dir [String, Pathname] a folder Typelizer wrote
      def self.use_interfaces!(dir)
        Dir[File.join(dir, '*.ts')].each do |file|
          next if File.basename(file) == 'index.ts'

          content = File.read(file)
          updated = content.gsub(/^type (\w+) = \{/, 'interface \1 {')
          File.write(file, updated) if updated != content
        end
      end

      # @param serializer_dirs [Array<String, Pathname>] directories to load before generating
      def self.call(serializer_dirs)
        serializer_dirs.each { |dir| Rails.autoloaders.main.eager_load_dir(dir.to_s) }

        # Before the SDK types, so two serializers disagreeing on a list's
        # values stop generation instead of one of them silently winning.
        require Spree::Api::Engine.root.join('lib/spree/api/enum_types').to_s
        Spree::Api::EnumTypes.new.write!(Spree::Api::Engine.root.join('../..'))

        require 'typelizer/generator'
        Typelizer::Generator.call(force: true)

        api_root = Spree::Api::Engine.root
        [api_root.join('../../packages/sdk/src/types/generated'), api_root.join('../../packages/admin-sdk/src/types/generated'),
         api_root.join('../../packages/admin-sdk/src/types/generated/emails')].each { |dir| use_interfaces!(dir) }

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
