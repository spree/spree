require 'spec_helper'

describe Spree::Admin::RootController do

  context "unauthorized request" do

    before :each do
      allow(controller).to receive(:spree_current_user).and_return(nil)
    end

    it "redirects to orders path by default" do
      get :index, use_route: 'admin'

      expect(response).to redirect_to '/admin/orders'
    end
  end

  context "authorized request" do
    stub_authorization!

    it "redirects to orders path by default" do
      get :index, use_route: 'admin'

      expect(response).to redirect_to '/admin/orders'
    end

    context "wherever admin_root_redirects_path tells it to" do
      before do
        expect(controller).to receive(:admin_root_redirect_path).and_return('/grooot')
      end

      it "redirects" do
        get :index, use_route: 'admin'

        expect(response).to redirect_to '/grooot'
      end
    end
  end
end
