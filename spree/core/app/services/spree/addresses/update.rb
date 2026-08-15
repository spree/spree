module Spree
  module Addresses
    class Update
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      def call(address:, address_params:, **opts)
        ApplicationRecord.transaction do
          perform(address: address, address_params: address_params, **opts)
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
        failure(e.record)
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
            user: address.customer,
            address_id: address.id,
            default_billing: default_billing,
            default_shipping: default_shipping
          )
        end

        return success(address) unless address_changed

        if address.editable?
          address.update!(address_params)

          if address.customer.present?
            assign_to_user_as_default(
              user: address.customer,
              address_id: address.id,
              default_billing: default_billing,
              default_shipping: default_shipping
            )
          end

          reassign_incomplete_orders(address.id, address)

          success(address)
        elsif new_address(address_params).valid?
          old_address_id = address.id
          address.destroy!

          if new_address.customer.present?
            default_billing = address.is_default_billing? || default_billing
            default_shipping = address.is_default_shipping || default_shipping

            assign_to_user_as_default(
              user: new_address.customer,
              address_id: new_address.id,
              default_billing: default_billing,
              default_shipping: default_shipping
            )
          end

          reassign_incomplete_orders(old_address_id, new_address)

          success(new_address)
        else
          failure(new_address)
        end
      end

      # An update that names no country keeps the one already on the address —
      # the edit forms post a partial set of fields.
      def prepare_address_params!(address, address_params)
        address_params[:customer_id] = address&.customer_id
        address_params[:country_iso] ||= address.country_iso
        address_params.transform_values!(&:presence)
      end

      def reassign_incomplete_orders(old_address_id, new_address)
        orders = Spree::Order.incomplete.where(customer_id: new_address.customer_id)
        orders.where(ship_address_id: old_address_id).update_all(ship_address_id: new_address.id, updated_at: Time.current)
        orders.where(bill_address_id: old_address_id).update_all(bill_address_id: new_address.id, updated_at: Time.current)
      end

      def defaults_changed?(address, default_billing, default_shipping)
        user = address.customer

        user.present? && (
          (default_billing.present? && user.bill_address != address) ||
          (default_shipping.present? && user.ship_address != address)
        )
      end

      # +find_or_create_by+ builds a WHERE clause from every key, so the ISO
      # handles have to be resolved to the columns they stand for first.
      def new_address(address_params = {})
        @new_address ||= ::Spree::Address.not_deleted.find_or_create_by(
          Spree::Address.resolve_geo_params(address_params.except(:id, :updated_at, :created_at))
        )
      end
    end
  end
end
