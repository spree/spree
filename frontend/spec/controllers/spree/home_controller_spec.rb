require 'spec_helper'

describe Spree::HomeController, :type => :controller do
  it "provides current user to the searcher class" do
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    allow(controller).to receive_messages :try_spree_current_user => user
    expect_any_instance_of(Spree::Config.searcher_class).to receive(:current_user=).with(user)
    spree_get :index
    expect(response.status).to eq(200)
  end

  context "layout" do
    it "renders default layout" do
      spree_get :index
      expect(response).to render_template(layout: 'spree/layouts/spree_application')
    end

    context "different layout specified in config" do
      before { Spree::Config.layout = 'layouts/application' }

      it "renders specified layout" do
        spree_get :index
        expect(response).to render_template(layout: 'layouts/application')
      end
    end
  end
end
