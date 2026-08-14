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

        # A code nothing recognises is rejected rather than stored: every
        # consumer matches codes verbatim, so a bad one silently matches
        # nothing. Gated on change so historical rows stay updatable even if
        # the registry's curation shifts under them.
        validate :country_iso_must_resolve, if: -> { new_record? || will_save_change_to_country_iso? }
        define_method(:country_iso_must_resolve) do
          return if country_iso.blank?

          errors.add(:country_iso, :invalid) if Spree::Country.by_iso(country_iso).nil?
        end
        private :country_iso_must_resolve

        return unless state

        normalizes :state_code, with: UPCASE

        # `state_code` is the canonical name, matching the tax tables; the
        # v3 API shipped `state_abbr`, kept as an alias.
        alias_attribute :state_abbr, :state_code

        # @return [Spree::State, nil]
        define_method(:state) do
          Spree::State.resolve(country_iso, state_code) if country_iso.present? && state_code.present?
        end

        # A subdivision code is only meaningful within its country, so it is
        # checked against the country's own list (retired codes resolve
        # through their successors). Without a country there is nothing to
        # check against — the code is left alone.
        validate :state_code_must_resolve,
                 if: -> { new_record? || will_save_change_to_state_code? || will_save_change_to_country_iso? }
        define_method(:state_code_must_resolve) do
          return if state_code.blank? || country_iso.blank?
          # An unresolvable country already got its own error.
          return if Spree::Country.by_iso(country_iso).nil?

          errors.add(:state_code, :invalid) if Spree::IsoData.subdivision_code(country_iso, state_code).nil?
        end
        private :state_code_must_resolve
      end
    end
  end
end
