module Spree
  class Admin::OverviewController < Admin::BaseController

    def index
    end

    def preferences
      [:app_id, :site_id, :token].each do |key|
        Spree::Dash::Config[key] = params[key]
      end
      redirect_to admin_path
    end

  end
end
