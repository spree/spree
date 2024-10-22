module Spree
  module Addresses
    class Create
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      attr_accessor :country

      def call(address_params: {}, user: nil, **opts)
        order = opts[:order]
        default_billing = opts.fetch(:default_billing, false)
        default_shipping = opts.fetch(:default_shipping, false)

        address_params = fill_country_and_state_ids(address_params)

        address = Spree::Address.new(address_params)
        address.user = user if user.present?

        ApplicationRecord.transaction do
          if address.save
            if user.present?
              if user.addresses.pluck(:id) == [address.id]
                user.update(bill_address_id: address.id, ship_address_id: address.id)
              else
                assign_to_user_as_default(
                  user: user,
                  address_id: address.id,
                  default_billing: default_billing,
                  default_shipping: default_shipping
                )
              end
            end

            assign_to_order(order: order, address_id: address.id) if order.present?
            success(address)
          else
            failure(address)
          end
        end
      end

      private

      def assign_to_order(order:, address_id:)
        order.update(ship_address_id: address_id, state: 'address')
      end
    end
  end
end
