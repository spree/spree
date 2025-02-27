module Spree
  module LocaleUrls
    extend ActiveSupport::Concern

    included do
      before_action :redirect_to_default_locale
    end

    private

    def default_url_options
      locale = current_locale == current_store.default_locale ? nil : current_locale

      super.merge(locale: locale, currency: currency_param)
    end

    def redirect_to_default_locale
      return if params[:locale].blank? || supported_locale?(params[:locale])

      redirect_to url_for(request.parameters.merge(locale: nil))
    end
  end
end
