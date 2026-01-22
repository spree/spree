module Spree
  module Api
    module V3
      module Store
        class AddressSerializer < BaseSerializer
          attributes :id, :firstname, :lastname, :full_name, :address1, :address2,
                     :city, :zipcode, :phone, :company, :state_id,
                     :state_text, :country_id, :country_iso, :country_name
        end
      end
    end
  end
end
