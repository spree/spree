class LocaleController < Spree::BaseController
  def set
    if request.referer && request.referer.starts_with?("http://" + request.host)
      session["user_return_to"] = request.referer
    end
    if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym)
      session[:locale] = I18n.locale = params[:locale].to_sym
      flash.notice = t(:locale_changed)
    else
      flash[:error] = t(:locale_not_changed)
    end
    redirect_back_or_default(root_path)
  end
end
