module Spree
  class Admin::OverviewController < Admin::BaseController
    before_filter :check_last_jirafe_sync_time, :only => :index

    JIRAFE_LOCALES = { :english => 'en_US',
                       :french => 'fr_FR',
                       :german => 'de_DE',
                       :japanese => 'ja_JA' }

    def index
      if session[:jirafe_unavailable_since]
        jirafe_unavailable_since = Time.at(session[:jirafe_unavailable_since])
        if jirafe_unavailable_since < Time.now - 10.minutes
          redirect_to admin_analytics_register_path if !dash_config.configured?
        end
      else
        redirect_to admin_analytics_register_path if !dash_config.configured?
      end

      if JIRAFE_LOCALES.values.include? params[:locale]
        Spree::Dash::Config.locale = params[:locale]
      end
    end

    private

    def check_last_jirafe_sync_time
      if Spree::Dash::Config.configured?
        if session[:last_jirafe_sync]
          hours_since_last_sync = ((DateTime.now - session[:last_jirafe_sync]) * 24).to_i
          redirect_to admin_analytics_sync_path if hours_since_last_sync > 24
        else
          redirect_to admin_analytics_sync_path
        end
      end
    end

    def model_class
      Spree::Admin::OverviewController
    end

    def dash_config
      Spree::Dash::Config
    end
  end
end
