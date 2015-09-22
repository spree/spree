require 'spec_helper'

module Spree
  module Admin
    RSpec.describe "AdminPath", type: :routing do
      it "shoud route to admin by default" do
        expect(spree.admin_path).to eq("/admin")
      end

      it "should route to the the configured path" do
        Spree.admin_path = "/secret"
        Rails.application.reload_routes!
        expect(spree.admin_path).to eq("/secret")

        # restore the path for other tests
        Spree.admin_path = "/admin"
        Rails.application.reload_routes!
        expect(spree.admin_path).to eq("/admin")
      end
    end
  end
end
