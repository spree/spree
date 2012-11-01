require 'spec_helper'

describe Spree::HomeController do
  it "should provide the current user to the searcher class" do
    user = stub(:last_incomplete_spree_order => nil)
    controller.stub :spree_current_user => user
    Spree::Config.searcher_class.any_instance.should_receive(:current_user=).with(user)
    spree_get :index
    response.status.should == 200
  end
end
