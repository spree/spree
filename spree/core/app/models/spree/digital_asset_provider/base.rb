module Spree
  module DigitalAssetProvider
    # Strategy that answers "how is this digital asset's deliverable produced?".
    #
    # Stored as a class-name string in `DigitalAsset#provider_type` and
    # constantized at call time; registered via `Spree.digital_asset_providers`.
    # A blank `provider_type` resolves to {File}, the default — so an uploaded
    # file is just the provider every asset already had.
    #
    # Unlike delivery-rate or tax providers, a digital-asset provider does NOT
    # resolve credentials through a `Spree::Integration`: it is host-app glue
    # into internal software and owns its own configuration. The base gives it
    # only the asset.
    class Base
      attr_reader :digital_asset

      SETTING_TYPES = %i[string number boolean select].freeze

      class << self
        # Declares one per-asset configuration field the dashboard renders when
        # a merchant adds an asset backed by this provider. Mirrors the
        # `preference` shape used elsewhere, but the values live on the
        # DigitalAsset (in `metadata`), not on the stateless provider instance.
        #
        # @param key [Symbol]
        # @param type [Symbol] one of {SETTING_TYPES}
        # @param default [Object]
        # @param in [Array] allowed values for a `:select` field
        def setting(key, type = :string, default: nil, in: nil)
          raise ArgumentError, "unknown setting type #{type}" unless SETTING_TYPES.include?(type)

          own_settings[key.to_sym] = {
            key: key.to_sym,
            type: type,
            default: default,
            in: binding.local_variable_get(:in)
          }.compact
        end

        # `[{ key:, type:, default:, in? }]` for every setting declared on this
        # provider and its ancestors. Same wire shape the admin form renders
        # from, so no provider ships dashboard code.
        #
        # @return [Array<Hash>]
        def settings_schema
          ancestors.reverse.each_with_object({}) do |ancestor, merged|
            merged.merge!(ancestor.own_settings) if ancestor.respond_to?(:own_settings)
          end.values
        end

        # @api private
        def own_settings
          @own_settings ||= {}
        end

        # Human-readable name for admin UIs. Provider gems following the
        # `SpreeAcme::LicenseProvider` convention get the outer module
        # ("Acme"); a bare in-app class gets its own titleized name.
        #
        # @return [String]
        def provider_name
          leaf = name.demodulize
          outer = name.deconstantize.delete_prefix('Spree')

          return leaf.titleize if outer.blank? || !leaf.end_with?('Provider')

          outer.delete_prefix('::')
        end

        # Whether an asset backed by this provider must carry an uploaded file.
        # {File} needs one; a provider that resolves its deliverable elsewhere
        # does not. Drives conditional validation and the admin create form.
        #
        # @return [Boolean]
        def requires_attachment?
          false
        end
      end

      # @param digital_asset [Spree::DigitalAsset]
      def initialize(digital_asset)
        @digital_asset = digital_asset
      end

      # Produces the deliverable for one authorized download.
      #
      # @param digital_link [Spree::DigitalLink] the authorized grant
      # @param expires_in [ActiveSupport::Duration] lifetime of any signed URL
      # @return [Spree::DigitalDelivery]
      def deliver(digital_link, expires_in:)
        raise NotImplementedError, "#{self.class} must implement #deliver"
      end
    end
  end
end
