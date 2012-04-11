require 'spec_helper'

describe Spree::Admin::OverviewController do

  before :each do
    @user = Factory(:admin_user)
    controller.stub :current_user => @user
  end

  it "sets the locale preference" do
    Spree::Dash::Config.locale = 'en_EN'
    spree_get :index, :locale => 'fr_FR'
    Spree::Dash::Config.locale.should eq 'fr_FR'
  end

end
