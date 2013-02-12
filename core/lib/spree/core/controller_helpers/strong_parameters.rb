module Spree
  module Core
    module ControllerHelpers
      module StrongParameters
        def permitted_order_attributes
          [:line_items_attributes, :coupon_code]
        end

        def permitted_address_attributes
           [:firstname, :lastname, :address1, :address2,
            :city, :country_id, :state_id, :zipcode, :phone]
        end

        def permitted_source_attributes
          [:number, :month, :year, :verification_value,
           :first_name, :last_name]
        end

        def permitted_payment_attributes
          [:payment_method_id, :source_attributes => permitted_source_attributes]
        end
      end
    end
  end
end
