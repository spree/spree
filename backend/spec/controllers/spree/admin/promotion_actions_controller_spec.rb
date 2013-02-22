require 'spec_helper'

describe Spree::Admin::PromotionActionsController do
  stub_authorization!

  let!(:promotion) { create(:promotion) }

  it "can create a promotion action of a valid type" do
    spree_post :create, :promotion_id => promotion.id, :action_type => "Spree::Promotion::Actions::CreateAdjustment"
    response.should be_redirect
    response.should redirect_to spree.edit_admin_promotion_path(promotion)
    promotion.actions.count.should == 1
  end

  it "can not create a promotion action of an invalid type" do
    spree_post :create, :promotion_id => promotion.id, :action_type => "Spree::InvalidType"
    response.should be_redirect
    response.should redirect_to spree.edit_admin_promotion_path(promotion)
    promotion.rules.count.should == 0
  end
end
