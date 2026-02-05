module Spree
  module Admin
    class AddressesController < ResourceController
      before_action :set_new_address_country, only: :new

      def create
        user = Spree.user_class.find(params[:user_id])

        result = create_service.call(
          address_params: permitted_resource_params,
          user: user,
          default_shipping: params[:default_shipping].to_b,
          default_billing: params[:default_billing].to_b
        )

        @address = @object = result.value

        set_current_store if result.success?
        flash.now[:success] = flash_message_for(@address, :successfully_created) if result.success?
      end

      def update
        order = address_user_current_order

        result = update_service.call(
          address: @address,
          address_params: permitted_resource_params,
          order: order,
          address_changes_except: address_update_address_changes_except
        )

        @address = @object = result.value

        set_current_store if result.success?
        flash.now[:success] = flash_message_for(@address, :successfully_updated) if result.success?
      end

      private

      def set_new_address_country
        @address.country = current_store.default_country
      end

      def create_service
        Spree.address_create_service
      end

      def update_service
        Spree.address_update_service
      end

      def address_update_address_changes_except
        []
      end

      def address_user_current_order
        incomplete_orders = @address.user.orders.incomplete
        incomplete_orders.where(ship_address: @address).or(incomplete_orders.where(bill_address: @address)).first
      end

      def location_after_save
        spree.admin_user_url(@address.user)
      end

      def collection_url
        if @address.user.present?
          spree.admin_user_url(@address.user)
        else
          spree.admin_users_url
        end
      end

      def permitted_resource_params
        params.require(:address).permit(Spree::PermittedAttributes.address_attributes)
      end
    end
  end
end
