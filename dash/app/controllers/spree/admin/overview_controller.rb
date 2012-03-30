module Spree
  class Admin::OverviewController < Admin::BaseController

    JIRAFE_LOCALES = { :english => 'en_US',
                       :french => 'fr_FR',
                       :german => 'de_DE' }

    def index
      if JIRAFE_LOCALES.values.include? params[:locale]
        Spree::Dash::Config.locale = params[:locale]
      end
    end

    def preferences
      [:app_id, :site_id, :token].each do |key|
        Spree::Dash::Config[key] = params[key]
      end
      redirect_to admin_path
    end

  end
end
