# A rule to limit a promotion based on shipment country. Stores an
# array of ISO codes — countries are inherently identified by ISO
# in the API. The legacy single `country_id` / `country_iso`
# preferences still work; they fold into the multi-country list.
module Spree
  class Promotion
    module Rules
      class Country < PromotionRule
        preference :country_isos, :array, default: [], parse_on_set: lambda { |values|
          normalize_id_preference.call(values).map(&:upcase)
        }
        preference :country_id, :integer # legacy single-country shortcut
        preference :country_iso, :string # legacy ISO-based shortcut

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def countries
          isos = preferred_country_isos.presence || [preferred_country_iso].compact_blank
          return Spree::Country.none if isos.blank?

          Spree::Country.where(iso: isos.map { |s| s.to_s.upcase })
        end

        def eligible?(order, options = {})
          allowed_isos = eligible_country_isos(order)
          shipping_iso = options[:country_iso] || order.ship_address&.country_iso

          return true if allowed_isos.include?(shipping_iso)

          eligibility_errors.add(:base, eligibility_error_message(:wrong_country))
          false
        end

        # Effective list of eligible country ISOs, merging legacy
        # single-country preferences into the multi-country list.
        # Order-of-precedence: explicit ISO list > legacy single ISO
        # > legacy single ID > store default. Memoized per-instance —
        # eligibility checks fire repeatedly per cart change.
        def eligible_country_isos(order = nil)
          @eligible_country_isos ||= compute_eligible_country_isos(order)
        end

        private

        def compute_eligible_country_isos(order)
          return preferred_country_isos.map { |v| v.to_s.upcase } if preferred_country_isos.present?
          return [preferred_country_iso.to_s.upcase] if preferred_country_iso.present?

          if preferred_country_id.present?
            iso = Spree::Country.where(id: preferred_country_id).pick(:iso)
            return [iso.to_s.upcase] if iso.present?
          end

          return [] if order.nil?

          [order.store&.default_country&.iso, order.store&.default_market&.default_country&.iso].compact.map(&:upcase).uniq
        end
      end
    end
  end
end
