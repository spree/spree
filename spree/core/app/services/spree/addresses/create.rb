module Spree
  module Addresses
    class Create
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      # @param owner [Object, nil] who keeps the address — a customer, a
      #   company node, anything with an address book. +user:+ is the older
      #   name for the same thing, from when only customers had one.
      def call(address_params: {}, owner: nil, user: nil, **opts)
        owner ||= user
        order = opts[:order]
        # nil, not false — the same three-state contract Update keeps, so
        # silence means the same thing on both.
        default_billing = address_params.key?(:is_default_billing) ? address_params.delete(:is_default_billing) : opts.fetch(:default_billing, nil)
        default_shipping = address_params.key?(:is_default_shipping) ? address_params.delete(:is_default_shipping) : opts.fetch(:default_shipping, nil)

        address = Spree::Address.new(address_params)
        address.owner = owner if owner.present?

        ApplicationRecord.transaction do
          if address.save
            if owner.present?
              # The first address a book gets is its default of both kinds —
              # there is nothing for it to displace.
              if owner.addresses.pluck(:id) == [address.id]
                assign_owner_default(owner: owner, address_id: address.id)
              else
                assign_owner_default(
                  owner: owner,
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
        order.update(ship_address_id: address_id)
      end
    end
  end
end
