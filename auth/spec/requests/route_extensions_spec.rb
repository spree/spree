require 'spec_helper'

describe Spree::Core::Rails::RouteExtensions do
  def reload_routes!
    Rails.application.routes_reloader.reload!
  end

  context "auth + core routes" do
    before do
      Rails.application.routes.prepend do
        spree
      end

      reload_routes!
    end

    it "routes to core" do
      visit '/'
      page.should have_content("Log In")
      page.status_code.should == 200

      visit '/login'
      page.status_code.should == 200
    end
  end
end
