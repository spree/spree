module Spree
  module Account
    module Addresses
      class Update
        prepend Spree::ServiceModule::Base
        include Spree::Account::Addresses::Helper

        attr_accessor :country

        def call(address:, address_params:)
          address_params[:country_id] ||= address.country_id
          fill_country_and_state_ids(address_params)

          if address.update(address_params)
            success(address)
          else
            failure(address)
          end
        end
      end
    end
  end
end
