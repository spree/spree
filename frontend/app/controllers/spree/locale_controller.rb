require 'uri'

module Spree
  class LocaleController < Spree::StoreController
    def index
      render :index, layout: false
    end

    def set
      new_locale = (params[:switch_to_locale] || params[:locale]).to_s

      if new_locale.present? && supported_locale?(new_locale)
        if request.env['HTTP_REFERER'].present? && request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
          redirect_to BuildLocalizedUrl.call(
            url: request.env['HTTP_REFERER'],
            locale: new_locale,
            default_locale: current_store.default_locale
          ).value
        else
          redirect_to root_path(locale: new_locale)
        end
      else
        redirect_to root_path
      end
    end
  end
end
