module Spree
  module Addresses
    class Update
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      attr_accessor :country

      def call(address:, address_params:, **opts)
        ApplicationRecord.transaction do
          perform(address: address, address_params: address_params, **opts)
        end
      end

      private

      def perform(address:, address_params:, **opts)
        default_billing = address_params.key?(:is_default_billing) ? address_params.delete(:is_default_billing) : opts.fetch(:default_billing, false)
        default_shipping = address_params.key?(:is_default_shipping) ? address_params.delete(:is_default_shipping) : opts.fetch(:default_shipping, false)
        address_changes_except = opts.fetch(:address_changes_except, [])

        prepare_address_params!(address, address_params)
        address.assign_attributes(address_params)

        address_changes = address.changes.except(*address_changes_except)

        # Ignore changes that are only different in case as encrypted fields are processed by rails as downcased
        address_changes.reject! do |attr, (old_val, new_val)|
          old_val.to_s.casecmp?(new_val.to_s)
        end

        address_changed = address_changes.any?
        if !address_changed && defaults_changed?(address, default_billing, default_shipping)
          assign_to_user_as_default(
            user: address.user,
            address_id: address.id,
            default_billing: default_billing,
            default_shipping: default_shipping
          )
        end

        return success(address) unless address_changed

        if address.editable?
          if address.update(address_params)
            if address.user.present?
              assign_to_user_as_default(
                user: address.user,
                address_id: address.id,
                default_billing: default_billing,
                default_shipping: default_shipping
              )

              reassign_incomplete_orders(address.user, address.id, address)
            end

            success(address)
          else
            failure(address)
          end
        elsif new_address(address_params).valid?
          old_address_id = address.id
          address.destroy

          if new_address.user.present?
            default_billing = address.user_default_billing? || default_billing
            default_shipping = address.user_default_shipping? || default_shipping

            assign_to_user_as_default(
              user: new_address.user,
              address_id: new_address.id,
              default_billing: default_billing,
              default_shipping: default_shipping
            )

            reassign_incomplete_orders(new_address.user, old_address_id, new_address)
          end

          success(new_address)
        else
          failure(new_address)
        end
      end

      def prepare_address_params!(address, address_params)
        address_params[:user_id] = address&.user_id
        address_params[:country_id] ||= address.country_id
        address_params = fill_country_and_state_ids(address_params)
        address_params.transform_values!(&:presence)
      end

      def reassign_incomplete_orders(user, old_address_id, new_address)
        orders = user.orders.incomplete.where('ship_address_id = :id OR bill_address_id = :id', id: old_address_id)

        orders.find_each do |incomplete_order|
          incomplete_order.ship_address = new_address if incomplete_order.ship_address_id == old_address_id
          incomplete_order.bill_address = new_address if incomplete_order.bill_address_id == old_address_id
          incomplete_order.state = 'address'
          incomplete_order.save!
        end
      end

      def defaults_changed?(address, default_billing, default_shipping)
        user = address.user

        user.present? && (
          (default_billing.present? && user.bill_address != address) ||
          (default_shipping.present? && user.ship_address != address)
        )
      end

      def new_address(address_params = {})
        @new_address ||= ::Spree::Address.not_deleted.find_or_create_by(address_params.except(:id, :updated_at, :created_at))
      end
    end
  end
end
