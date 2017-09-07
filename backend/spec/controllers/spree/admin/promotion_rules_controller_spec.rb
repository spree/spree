require 'spec_helper'

describe Spree::Admin::PromotionRulesController, type: :controller do
  stub_authorization!

  let!(:promotion) { create(:promotion) }

  it 'can create a promotion rule of a valid type' do
    spree_post :create, promotion_id: promotion.id, promotion_rule: { type: 'Spree::Promotion::Rules::Product' }
    expect(response).to be_redirect
    expect(response).to redirect_to spree.edit_admin_promotion_path(promotion)
    expect(promotion.rules.count).to eq(1)
  end

  it 'can not create a promotion rule of an invalid type' do
    spree_post :create, promotion_id: promotion.id, promotion_rule: { type: 'Spree::InvalidType' }
    expect(response).to be_redirect
    expect(response).to redirect_to spree.edit_admin_promotion_path(promotion)
    expect(promotion.rules.count).to eq(0)
  end
end
