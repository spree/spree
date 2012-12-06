module Spree
  class Admin::OverviewController < Admin::BaseController
    before_filter :check_last_jirafe_sync_time, :only => :index

    JIRAFE_LOCALES = { :english => 'en_US',
                       :french => 'fr_FR',
                       :german => 'de_DE',
                       :japanese => 'ja_JA' }

    def index
      redirect_to admin_analytics_register_path unless Spree::Dash::Config.configured?

      if JIRAFE_LOCALES.values.include? params[:locale]
        Spree::Dash::Config.locale = params[:locale]
      end
    end

    private

    def check_last_jirafe_sync_time
      if session[:last_jirafe_sync]
        hours_since_last_sync = ((DateTime.now - session[:last_jirafe_sync]) * 24).to_i
        redirect_to admin_analytics_sync_path if hours_since_last_sync > 24
      else
        redirect_to admin_analytics_sync_path
      end
    end
  end
end
