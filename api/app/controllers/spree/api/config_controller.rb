module Spree
  module Api
    class ConfigController < Spree::Api::BaseController
      def money
        render json: ::Money.new(1, Spree::Config[:currency])
      end

      def show
        render json: { default_country_id: Spree::Config[:default_country_id] }
      end
    end
  end
end
