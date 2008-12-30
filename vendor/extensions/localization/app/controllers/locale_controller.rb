class LocaleController < ApplicationController

  def set
    if params[:locale]
      I18n.locale = params[:locale]
      session[:locale] = params[:locale]
      flash[:notice] = t("locale_changed")
    end
    redirect_to (request.env['HTTP_REFERER'] or root_path)
  end

end
