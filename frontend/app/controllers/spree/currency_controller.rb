module Spree
  class CurrencyController < StoreController
    def set
      new_currency = params[:switch_to_currency]&.upcase

      if new_currency.present? && supported_currency?(new_currency)
        current_order&.update(currency: new_currency)
        session[:currency] = new_currency
      end
      redirect_back_or_default(root_path(currency: new_currency))
    end
  end
end
