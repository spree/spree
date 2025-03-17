module Spree
  module Admin
    module Orders
      class PaymentLinksController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern

        before_action :load_order
        before_action :ensure_frontend_available

        def create
          recipient_email = @order.user&.email || @order.email

          if recipient_email.present?
            Spree::OrderMailer.payment_link_email(@order.id).deliver_later
            flash[:success] = Spree.t('admin.orders.payment_link_sent')
          else
            flash[:error] = Spree.t('admin.orders.no_email_present')
          end

          redirect_back fallback_location: spree.edit_admin_order_url(@order)
        end

        private

        def ensure_frontend_available
          unless Spree::Core::Engine.frontend_available? && spree.respond_to?(:checkout_state_url)
            redirect_to spree.edit_admin_order_url(@order)
          end
        end
      end
    end
  end
end
