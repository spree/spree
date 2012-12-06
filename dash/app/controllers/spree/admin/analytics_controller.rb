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
        redirect_to admin_path
      rescue Spree::Dash::JirafeException => e
        flash[:error] = e.message
        redirect_to root_path
      end
    end

    def sync
      begin
        store = Spree::Dash::Jirafe.synchronize_resources(store_hash)
        session[:last_jirafe_sync] = DateTime.now
        flash[:notice] = "Updated"
        redirect_to admin_path
      rescue Spree::Dash::JirafeException => e
        flash[:error] = e.message
        redirect_to admin_path
      end
    end

    def update
      Spree::Dash::Config.app_id = params[:app_id]
      Spree::Dash::Config.app_token = params[:app_token]
      Spree::Dash::Config.site_id = params[:site_id]
      Spree::Dash::Config.token = params[:token]
      flash[:success] = t(:jirafe_settings_updated, :scope => "spree.dash")
      redirect_to admin_analytics_path
    end

    private

    def redirect_if_registered
      if Spree::Dash::Config.configured?
        flash[:success] = t(:already_signed_up_for_analytics)
        redirect_to admin_path and return true
      end
    end

    def store_hash
      url = Spree::Config.site_url || "http://demo.spreecommerce.com"
      email = "junk@spreecommerce.com"
      name = Spree::Config.site_name || "Spree Store"

      store = {
        :first_name    => 'Spree',
        :last_name     => 'User',
        :email         => email,
        :name          => 'Spree Store Dos',
        :url           => format_url(url),
        :platform_type => 'spree-development',
        :currency      => 'USD',
        :time_zone     => ActiveSupport::TimeZone::MAPPING['Eastern Time (US & Canada)'],
      }

      if Spree::Dash::Config.app_id.present? && Spree::Dash::Config.app_token.present?
        store[:app_id] = Spree::Dash::Config.app_id
        store[:app_token] = Spree::Dash::Config.app_token
      end
      store
    end

    def format_url(url)
      url =~ /^http/ ? url : "http://#{url}"
    end
  end
end
