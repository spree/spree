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

        if result.success?
          set_current_store

          flash[:success] = flash_message_for(@address, :successfully_created)
          redirect_to location_after_save, status: :see_other
        else
          render action: :edit, status: :unprocessable_entity
        end
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

        if result.success?
          set_current_store

          flash[:success] = flash_message_for(@address, :successfully_updated)
          redirect_to location_after_save, status: :see_other
        else
          render action: :edit, status: :unprocessable_entity
        end
      end

      private

      def set_new_address_country
        @address.country = current_store.default_country
      end

      def create_service
        Spree::Dependencies.address_create_service.constantize
      end

      def update_service
        Spree::Dependencies.address_update_service.constantize
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
    end
  end
end
