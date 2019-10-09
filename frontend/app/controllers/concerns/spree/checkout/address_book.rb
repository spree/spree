# https://github.com/spree-contrib/spree_address_book/blob/master/app/controllers/spree/checkout_controller_decorator.rb
module Spree
  module Checkout
    module AddressBook
      extend ActiveSupport::Concern

      included do
        after_action :normalize_addresses, only: :update
        before_action :set_addresses, only: :update
      end

      protected

      def set_addresses
        return unless params[:order] && params[:state] == 'address'

        if params[:order][:ship_address_id].to_i > 0
          params[:order].delete(:ship_address_attributes)

          Spree::Address.find(params[:order][:ship_address_id]).user_id != try_spree_current_user&.id && raise('Frontend address forging')
        else
          params[:order].delete(:ship_address_id)
        end

        if params[:order][:bill_address_id].to_i > 0
          params[:order].delete(:bill_address_attributes)

          Spree::Address.find(params[:order][:bill_address_id]).user_id != try_spree_current_user&.id && raise('Frontend address forging')
        else
          params[:order].delete(:bill_address_id)
        end
      end

      def normalize_addresses
        return unless params[:state] == 'address' && @order.bill_address_id && @order.ship_address_id

        # ensure that there is no validation errors and addresses were saved
        return unless @order.bill_address && @order.ship_address

        bill_address = @order.bill_address
        ship_address = @order.ship_address
        if @order.bill_address_id != @order.ship_address_id && bill_address == ship_address
          @order.update_column(:bill_address_id, ship_address.id)
          bill_address.destroy
        elsif params[:save_user_address]
          bill_address.update_attribute(:user_id, try_spree_current_user&.id)
        end

        ship_address.update_attribute(:user_id, try_spree_current_user&.id) if params[:save_user_address]
      end
    end
  end
end
