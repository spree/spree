module Spree
  module Addresses
    class Update
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      attr_accessor :country

      def call(address:, address_params:)
        address_params[:country_id] ||= address.country_id
        address_params = fill_country_and_state_ids(address_params)

        if address&.editable?
          address.update(address_params) ? success(address) : failure(address)
        else
          if new_address(address_params).valid?
            address.destroy
            success(new_address)
          else
            failure(new_address)
          end
        end
      end

      private

      def new_address(address_params = {})
        @new_address ||= ::Spree::Address.find_or_create_by(address_params.except(:id, :updated_at, :created_at))
      end
    end
  end
end
