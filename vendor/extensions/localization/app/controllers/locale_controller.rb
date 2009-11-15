class LocaleController < ApplicationController

  def set
    if params[:locale]
      I18n.locale = params[:locale]
      session[:locale] = params[:locale]
      flash[:notice] = t("locale_changed")
    end
    redirect_back_or_default(root_path)
  end

end
