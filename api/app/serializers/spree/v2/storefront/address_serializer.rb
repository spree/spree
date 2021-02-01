module Spree
  module V2
    module Storefront
      class AddressSerializer < BaseSerializer
        set_type :address

        attributes(*Spree::Address.serializer_attibutes)

        attribute :state_code do |address|
          address.state_abbr
        end

        attribute :state_name do |address|
          address.state_name_text
        end
      end
    end
  end
end
