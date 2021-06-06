module Spree
  module CartMethods
    extend ActiveSupport::Concern

    included do
      before_action :set_current_order
      before_action :check_authorization
    end

    private

    def assign_order_with_lock
      @order = current_order(lock: true)
      unless @order
        flash[:error] = Spree.t(:order_not_found)
        redirect_to spree.root_path && return
      end
    end

    def check_authorization
      return if current_order.nil?

      authorize! :edit, current_order, cookies.signed[:token]
    end
  end
end
