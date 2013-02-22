require 'spec_helper'

describe Spree::Admin::PromotionRulesController do
  stub_authorization!

  let!(:promotion) { create(:promotion) }

  it "can create a promotion rule of a valid type" do
    spree_post :create, :promotion_id => promotion.id, :promotion_rule => { :type => "Spree::Promotion::Rules::Product" }
    response.should be_redirect
    response.should redirect_to spree.edit_admin_promotion_path(promotion)
    promotion.rules.count.should == 1
  end

  it "can not create a promotion rule of an invalid type" do
    spree_post :create, :promotion_id => promotion.id, :promotion_rule => { :type => "Spree::InvalidType" }
    response.should be_redirect
    response.should redirect_to spree.edit_admin_promotion_path(promotion)
    promotion.rules.count.should == 0
  end
end
