module Spree
  module Addresses
    class Create
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      attr_accessor :country

      def call(address_params: {}, user: nil)
        address_params = fill_country_and_state_ids(address_params)

        address = Spree::Address.new(address_params)
        address.user = user if user.present?

        if address.save
          assign_to_user_as_default(user: user, address_id: address.id) if user.present?
          success(address)
        else
          failure(address)
        end
      end
    end
  end
end
