# A rule to limit a promotion based on shipment country. Stores an
# array of ISO codes — countries are inherently identified by ISO
# in the API. The legacy single `country_id` / `country_code`
# preferences still work; they fold into the multi-country list.
#
# Rules saved before the `country_iso` → `country_code` rename keep their
# old preference keys in the serialized hash, so reads fall back to them.
module Spree
  class Promotion
    module Rules
      class Country < Spree::PromotionRule
        preference :country_codes, :array, default: [], parse_on_set: lambda { |values|
          normalize_id_preference.call(values).map(&:upcase)
        }
        preference :country_id, :integer # legacy single-country shortcut
        preference :country_code, :string # legacy ISO-based shortcut

        def applicable?(promotable)
          promotable.is_a?(Spree::Order) || promotable.is_a?(Spree::Cart)
        end

        def countries
          isos = configured_country_codes.presence || [configured_country_code].compact_blank
          isos = [legacy_country_code(preferred_country_id)].compact_blank if isos.blank? && preferred_country_id.present?
          return [] if isos.blank?

          isos.filter_map { |iso| Spree::Country.by_iso(iso) }
        end

        def eligible?(order, options = {})
          allowed_isos = eligible_country_codes(order)
          shipping_iso = options[:country_code] || order.ship_address&.country_code

          return true if allowed_isos.include?(shipping_iso)

          eligibility_errors.add(:base, eligibility_error_message(:wrong_country))
          false
        end

        # Effective list of eligible country ISOs, merging legacy
        # single-country preferences into the multi-country list.
        # Order-of-precedence: explicit ISO list > legacy single ISO
        # > legacy single ID > store default. Memoized per-instance —
        # eligibility checks fire repeatedly per cart change.
        def eligible_country_codes(order = nil)
          @eligible_country_codes ||= compute_eligible_country_codes(order)
        end

        private

        # The stored hash still holds `country_isos` on rules saved before the
        # rename, and nothing rewrites it — so read both keys.
        def configured_country_codes
          preferred_country_codes.presence || Array(preferences[:country_isos])
        end

        def configured_country_code
          preferred_country_code.presence || preferences[:country_iso].presence
        end

        def compute_eligible_country_codes(order)
          return configured_country_codes.map { |v| v.to_s.upcase } if configured_country_codes.present?
          return [configured_country_code.to_s.upcase] if configured_country_code.present?

          if preferred_country_id.present?
            iso = legacy_country_code(preferred_country_id)
            return [iso.upcase] if iso.present?
          end

          return [] if order.nil?

          [order.store&.default_country&.iso, order.store&.default_market&.default_country&.iso].compact.map(&:upcase).uniq
        end

        # Countries stopped being records in 6.0, so a rule still configured
        # with the legacy row id is resolved by reading the table the upgrade
        # keeps until 6.1. Rules saved since store the ISO code directly.
        def legacy_country_code(country_id)
          connection = ActiveRecord::Base.connection
          return nil unless connection.table_exists?('spree_countries')

          connection.select_value(
            "SELECT iso FROM spree_countries WHERE id = #{connection.quote(country_id)}"
          )
        end
      end
    end
  end
end
