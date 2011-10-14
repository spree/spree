require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::GeneralSettingsController do
  before :each do 
    controller.stub :current_user => mock
  end

  it "saves dismissed alerts in a preference" do
    Spree::Config.set :dismissed_spree_alerts => "1"
    xhr :post, :dismiss_alert, :alert_id => 2
    response.response_code.should == 200
    Spree::Config[:dismissed_spree_alerts].should eq "1,2"
  end

end


