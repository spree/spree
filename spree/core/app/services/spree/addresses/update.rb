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
          assign_owner_default(
            owner: address.owner,
            address_id: address.id,
            default_billing: default_billing,
            default_shipping: default_shipping
          )
        end

        return success(address) unless address_changed

        if address.editable?
          address.update!(address_params)

          assign_owner_default(
            owner: address.owner,
            address_id: address.id,
            default_billing: default_billing,
            default_shipping: default_shipping
          )

          reassign_incomplete_orders(address.id, address)

          success(address)
        elsif new_address(address_params).valid?
          old_address_id = address.id
          address.destroy!

          if new_address.owner.present?
            # A replacement inherits whatever the row it replaces was default
            # for, so the owner keeps prefilling with the same site.
            default_billing = address.is_default_billing? || default_billing
            default_shipping = address.is_default_shipping? || default_shipping

            assign_owner_default(
              owner: new_address.owner,
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
        address_params[:owner_type] = address&.owner_type
        address_params[:owner_id] = address&.owner_id
        address_params[:country_code] ||= address.country_code
        address_params.transform_values!(&:presence)
      end

      # Keyed on the customer who started the order — which for a guest is no
      # customer at all, so a guest's carts are matched by the same nil. A
      # company book's entries are skipped: an order belongs to the person who
      # placed it, never to the organization's address book.
      def reassign_incomplete_orders(old_address_id, new_address)
        return if new_address.business_owned?

        orders = Spree::Order.incomplete.where(customer_id: new_address.owner_id)
        orders.where(ship_address_id: old_address_id).update_all(ship_address_id: new_address.id, updated_at: Time.current)
        orders.where(bill_address_id: old_address_id).update_all(bill_address_id: new_address.id, updated_at: Time.current)
      end

      # Whether this edit only moves the owner's default pointers, leaving the
      # address itself untouched — asked of whichever owner keeps the book.
      def defaults_changed?(address, default_billing, default_shipping)
        owner = address.owner
        return false unless owner.respond_to?(:default_address_id)

        (default_billing.present? && owner.default_address_id(:bill) != address.id) ||
          (default_shipping.present? && owner.default_address_id(:ship) != address.id)
      end

      def new_address(address_params = {})
        @new_address ||= ::Spree::Address.find_duplicate(address_params) ||
                         ::Spree::Address.create(
                           Spree::Address.resolve_geo_params(address_params.except(:id, :updated_at, :created_at))
                         )
      end
    end
  end
end
