module Spree
  module LocaleUrls
    extend ActiveSupport::Concern

    included do
      before_action :redirect_to_default_locale
    end

    private

    def default_url_options
      locale = if current_store.default_locale.nil? || current_locale == current_store.default_locale
                 nil
               else
                 current_locale
               end

      super.merge(locale: locale, currency: currency_param)
    end

    def redirect_to_default_locale
      return if params[:locale].blank? || supported_locale?(params[:locale])

      # Only include safe parameters in the redirect
      safe_params = {
        controller: params[:controller],
        action: params[:action],
        locale: nil
      }

      # Add any additional safe parameters that should be preserved
      %i[id format currency category_id tag].each do |param|
        safe_params[param] = params[param] if params[param].present?
      end

      redirect_to url_for(safe_params)
    end
  end
end
