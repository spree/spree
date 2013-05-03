require 'spec_helper'

describe Spree::HomeController do
  it "provides current user to the searcher class" do
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    controller.stub :try_spree_current_user => user
    Spree::Config.searcher_class.any_instance.should_receive(:current_user=).with(user)
    spree_get :index
    response.status.should == 200
  end

  context "layout" do
    it "renders default layout" do
      spree_get :index
      response.should render_template(layout: 'spree/layouts/spree_application')
    end

    context "different layout specified in config" do
      before { Spree::Config.layout = 'layouts/application' }

      it "renders specified layout" do
        spree_get :index
        response.should render_template(layout: 'layouts/application')
      end
    end
  end
end
