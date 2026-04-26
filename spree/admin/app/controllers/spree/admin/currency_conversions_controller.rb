# frozen_string_literal: true

module Spree
  module Admin
    class CurrencyConversionsController < BaseController
      skip_before_action :authorize_admin
      before_action :authorize_currency_conversion

      # GET /admin/currency_conversions?amount=99&from=USD&to=EUR,GBP
      def index
        conversions = Spree::Admin::FrankfurterCurrencyConversion.convert(
          amount: params[:amount],
          from: params[:from],
          to: params[:to].to_s.split(',')
        )

        render json: { conversions: conversions.transform_values(&:to_f) }
      end

      private

      def authorize_currency_conversion
        authorize! :manage, Spree::Price
      end
    end
  end
end
