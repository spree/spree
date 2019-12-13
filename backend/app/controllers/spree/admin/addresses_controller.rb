module Spree
  module Admin
    class AddressesController < ResourceController
      helper Spree::Admin::AddressesHelper

      def update
        if @address.editable?
          if @address.update(address_params)
            flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:address))
            redirect_to addresses_admin_user_path(@address.user)
          else
            render :edit
          end
        else
          new_address = @address.clone
          new_address.attributes = address_params
          @address.update_attribute(:deleted_at, Time.current)
          if new_address.save
            flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:address))
            redirect_to addresses_admin_user_path(@address.user)
          else
            render :edit
          end
        end
      end

      private

      def address_params
        params[:address].permit(
          :address,
          :firstname,
          :lastname,
          :address1,
          :address2,
          :city,
          :state_id,
          :zipcode,
          :country_id,
          :phone,
          :user_id
        )
      end
    end
  end
end
