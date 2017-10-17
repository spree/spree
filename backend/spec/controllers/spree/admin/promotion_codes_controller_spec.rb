require 'spec_helper'

describe Spree::Admin::PromotionCodesController do
  stub_authorization!
  render_views

  let!(:promotion) { create(:promotion) }
  let!(:code1) { create(:promotion_code, promotion: promotion) }
  let!(:code2) { create(:promotion_code, promotion: promotion) }
  let!(:code3) { create(:promotion_code, promotion: promotion) }

  it 'can create a promotion rule of a valid type' do
    spree_get :index, promotion_id: promotion.id, format: 'csv'
    expect(response).to be_success
    parsed = CSV.parse(response.body, headers: true)
    expect(parsed.entries.map(&:to_h)).to eq([ { 'Code' => code1.value }, { 'Code' => code2.value }, { 'Code' => code3.value }])
  end
end
