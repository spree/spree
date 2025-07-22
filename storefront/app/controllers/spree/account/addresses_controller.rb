module Spree
  module Account
    class AddressesController < BaseController
      include Spree::AddressesHelper

      # GET /account/addresses
      def index
        @addresses = user_available_addresses.includes(:user)
      end

      def accurate_title
        Spree.t(:my_addresses)
      end
    end
  end
end
