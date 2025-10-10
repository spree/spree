# A rule to limit a promotion based on shipment country.
module Spree
  class Promotion
    module Rules
      class Country < PromotionRule
        preference :country_id, :integer
        preference :country_iso, :string # Alternative way to configure the rule

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          if preferred_country_iso.present?
            validate_eligibility_by_country_iso(order)
          else
            validate_eligibility_by_country_id(order, options)
          end
        end

        private

        def validate_eligibility_by_country_id(order, options)
          country_id = options[:country_id] || order.ship_address.try(:country_id)
          return true if country_id == (preferred_country_id || order.store.default_country_id)

          eligibility_errors.add(:base, eligibility_error_message(:wrong_country))
          false
        end

        def validate_eligibility_by_country_iso(order)
          country_iso = order.ship_address&.country_iso
          return true if country_iso == (preferred_country_iso || order.store.default_country_iso)

          eligibility_errors.add(:base, eligibility_error_message(:wrong_country))
          false
        end
      end
    end
  end
end
