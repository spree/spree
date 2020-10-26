module Spree
  class CurrencyController < StoreController
    def set
      @currency = supported_currencies.find { |currency| currency.iso_code == params[:currency] }
      # Make sure that we update the current order, so the currency change is reflected.
      current_order&.update_attributes!(currency: @currency.iso_code)
      session[:currency] = params[:currency] if Spree::Config[:show_store_currency_selector]
      respond_to do |format|
        format.json { render json: !@currency.nil? }
        format.html do
          # We want to go back to where we came from!
          redirect_back_or_default(root_path)
        end
      end
    end
  end
end
