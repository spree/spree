module Spree
  module Admin
    class CustomerReturnsController < ResourceController
      add_breadcrumb_icon 'receipt-refund'
      add_breadcrumb Spree.t(:returns), :admin_customer_returns_path
      add_breadcrumb Spree.t(:customer_returns), :admin_customer_returns_path

      def index; end
    end
  end
end
