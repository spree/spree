# A rule to limit a promotion based on shipment country.
module Spree
  class Promotion
    module Rules
      class Country < PromotionRule
        preference :country_id, :integer

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          country_id = options[:country_id] || order.ship_address.try(:country_id)
          unless country_id.eql?(preferred_country_id || Spree::Country.default)
            eligibility_errors.add(:base, eligibility_error_message(:wrong_country))
          end

          eligibility_errors.empty?
        end
      end
    end
  end
end
