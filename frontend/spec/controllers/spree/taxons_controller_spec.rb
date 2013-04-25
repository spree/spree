require 'spec_helper'

describe Spree::TaxonsController do
  it "should provide the current user to the searcher class" do
    taxon = create(:taxon, :permalink => "test")
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    controller.stub :spree_current_user => user
    Spree::Config.searcher_class.any_instance.should_receive(:current_user=).with(user)
    spree_get :show, :id => taxon.permalink
    response.status.should == 200
  end
end
