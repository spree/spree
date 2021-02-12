module Spree
  class LocaleController < Spree::StoreController
    def index
      render :index, layout: false
    end

    def set
      session[:locale] = params[:locale]
      redirect_back_or_default(root_path(locale: current_locale))
    end
  end
end
