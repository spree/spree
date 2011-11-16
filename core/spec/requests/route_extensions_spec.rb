require 'spec_helper'

describe Spree::Core::Rails::RouteExtensions do
  context "default routes" do
    before do
      Rails.application.routes.prepend do
        spree :only => :core
      end

      Rails.application.routes_reloader.reload!
    end

    it "routes to core" do
      visit '/'
    end
  end
end

