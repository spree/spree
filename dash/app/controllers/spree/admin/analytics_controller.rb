module Spree
  class Admin::AnalyticsController < Admin::BaseController
    before_filter :redirect_if_registered

    def sign_up
      @store = {
        :first_name => '',
        :last_name => '',
        :email => try_spree_current_user.email,
        :currency => 'USD',
        :time_zone => Time.zone,
        :name => Spree::Config.site_name,
        :url => format_url(Spree::Config.site_url)
      }
    end

    def register
      @store = params[:store]
      @store[:url] = format_url(@store[:url])

      unless @store.has_key? :terms_of_service
        flash[:error] = t(:agree_to_terms_of_service)
        return render :sign_up
      end

      unless @store.has_key? :privacy_policy
        flash[:error] = t(:agree_to_privacy_policy)
        return render :sign_up
      end

      begin
        @store = Spree::Dash::Jirafe.register(@store)
        Spree::Dash::Config.app_id = @store[:app_id]
        Spree::Dash::Config.app_token = @store[:app_token]
        Spree::Dash::Config.site_id = @store[:site_id]
        Spree::Dash::Config.token = @store[:site_token]
        flash[:notice] = t(:successfully_signed_up_for_analytics)
        redirect_to admin_path
      rescue Spree::Dash::JirafeException => e
        flash[:error] = e.message
        render :sign_up
      end
    end

    private

    def redirect_if_registered
      if Spree::Dash::Config.configured?
        flash[:success] = t(:already_signed_up_for_analytics)
        redirect_to admin_path
      end
    end

    def format_url(url)
      url =~ /^http/ ? url : "http://#{url}"
    end

  end
end
