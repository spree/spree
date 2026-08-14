module Spree
  # Geography as reference data (docs/plans/6.0-drop-country-state-models.md):
  # a model stores ISO codes — `country_iso`, and `state_code` where
  # subdivisions matter — and reads them back as {Spree::Country} /
  # {Spree::State} value objects.
  #
  #   class Spree::StockLocation < Spree.base_class
  #     has_iso_geography
  #   end
  #
  # Included into {Spree::Base}, so the macro is available on every model and
  # nothing happens until one calls it. Callers assign codes — the macro
  # defines no country=/state= object writers; a model that needs them
  # ({Spree::Address}) layers its own on top.
  module HasIsoGeography
    extend ActiveSupport::Concern

    # Matching compares stored codes verbatim, so 'us' has to become 'US'
    # before it is written. Applied through +normalizes+, it also normalizes
    # values passed to `where` queries against these columns.
    UPCASE = ->(value) { value.presence&.to_s&.upcase }

    class_methods do
      # @param state [Boolean] whether the model also carries a `state_code` column
      def has_iso_geography(state: true)
        normalizes :country_iso, with: UPCASE

        # @return [Spree::Country, nil]
        define_method(:country) do
          Spree::Country.by_iso(country_iso) if country_iso.present?
        end

        return unless state

        normalizes :state_code, with: UPCASE

        # `state_code` is the canonical name, matching the tax tables; the
        # v3 API shipped `state_abbr`, kept as an alias.
        alias_attribute :state_abbr, :state_code

        # @return [Spree::State, nil]
        define_method(:state) do
          Spree::State.resolve(country_iso, state_code) if country_iso.present? && state_code.present?
        end
      end
    end
  end
end
