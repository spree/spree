module Spree
  module Account
    module Addresses
      class Create < ::Spree::Account::Addresses::Base
        def call(user:, address_params:)
          fill_country_and_state_ids(address_params)

          address = user.addresses.new(address_params)
          if address.save
            success(address)
          else
            failure(address)
          end
        end
      end
    end
  end
end
