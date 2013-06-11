module Spree
  class Admin::AnalyticsController < Admin::BaseController

    def register
      redirect_if_registered and return

      begin
        store = Spree::Dash::Jirafe.register(store_hash)
        Spree::Dash::Config.app_id = store[:app_id]
        Spree::Dash::Config.app_token = store[:app_token]
        Spree::Dash::Config.site_id = store[:site_id]
        Spree::Dash::Config.token = store[:site_token]
        Spree::Dash::Config.jirafe_available = true
        redirect_to admin_path

      rescue Spree::Dash::JirafeUnavailable => e
        session[:jirafe_unavailable_since] = Time.now.to_i
        flash[:error] = e.message
        Spree::Dash::Config.jirafe_available = false
        redirect_to spree.admin_path
      rescue Spree::Dash::JirafeException => e
        flash[:error] = e.message
        redirect_to root_path
      end
    end

    def sync
      session[:last_jirafe_sync] = DateTime.now
      begin
        store = Spree::Dash::Jirafe.synchronize_resources(store_hash)
      rescue SocketError
        flash[:error] = Spree.t(:could_not_connect_to_jirafe)
      rescue Spree::Dash::JirafeException => e
        flash[:error] = e.message
      ensure
        redirect_to admin_path
      end
    end

    def update
      Spree::Dash::Config.app_id = params[:app_id]
      Spree::Dash::Config.app_token = params[:app_token]
      Spree::Dash::Config.site_id = params[:site_id]
      Spree::Dash::Config.token = params[:token]
      flash[:success] = Spree.t(:jirafe_settings_updated, :scope => "dash")
      redirect_to admin_analytics_path
    end

    private

    def redirect_if_registered
      if Spree::Dash::Config.configured?
        flash[:success] = Spree.t(:already_signed_up_for_analytics)
        redirect_to admin_path and return true
      end
    end

    def store_hash
      if Spree::Config.site_url.blank? || Spree::Config.site_url.include?("localhost")
        url = "http://demo.spreecommerce.com"
      else
        url = Spree::Config.site_url
      end

      email = "junk@spreecommerce.com"
      name = Spree::Config.site_name || "Spree Store"

      store = {
        :first_name    => 'Spree',
        :last_name     => 'User',
        :email         => email,
        :name          => 'Spree Store',
        :url           => format_url(url),
        :currency      => 'USD',
        :time_zone     => ActiveSupport::TimeZone::MAPPING['Eastern Time (US & Canada)'],
      }

      if Spree::Dash::Config.configured?
        store[:app_id] = Spree::Dash::Config.app_id
        store[:app_token] = Spree::Dash::Config.app_token
        store[:site_id] = Spree::Dash::Config.site_id
      end
      store
    end

    def format_url(url)
      url =~ /^http/ ? url : "http://#{url}"
    end
  end
end
