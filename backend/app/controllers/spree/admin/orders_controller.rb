module Spree
  module Admin
    class OrdersController < Spree::Admin::BaseController
      def index
        # Dummy thing for Ember
      end

      private 
      def ember?
        true
      end
    end
  end
end
