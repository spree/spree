class LocaleController < ApplicationController

  def set
    Locale.code = params[:locale]
    session[:locale] = params[:locale]
    flash[:notice] = t("Locale changed")
    redirect_to (request.env['HTTP_REFERER'] or root_path)
  end

end
