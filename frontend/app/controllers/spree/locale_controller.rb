module Spree
  class LocaleController < Spree::StoreController
    def set
      if request.referer && request.referer.starts_with?('http://' + request.host)
        session['user_return_to'] = request.referer
      end
      if params[:locale] && I18n.available_locales.map(&:to_s).include?(params[:locale])
        session[:locale] = I18n.locale = params[:locale]
        flash.notice = Spree.t(:locale_changed)
      else
        flash[:error] = Spree.t(:locale_not_changed)
      end
      redirect_back_or_default(spree.root_path)
    end
  end
end
