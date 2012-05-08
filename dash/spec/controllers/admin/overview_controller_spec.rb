require 'spec_helper'

describe Spree::Admin::OverviewController do

  before :each do
    @user = create(:admin_user)
    controller.stub :current_spree_user => @user
  end

  it "sets the locale preference" do
    Spree::Dash::Config.locale = 'en_EN'
    spree_get :index, :locale => 'fr_FR'
    Spree::Dash::Config.locale.should eq 'fr_FR'
  end

end
