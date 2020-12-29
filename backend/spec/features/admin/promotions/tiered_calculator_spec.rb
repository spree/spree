require 'spec_helper'

describe 'Tiered Calculator Promotions' do
  stub_authorization!

  let(:promotion) { create :promotion }

  before do
    visit spree.edit_admin_promotion_path(promotion)
  end

  it 'adding a tiered percent calculator', js: true do
    select2 'Create whole-order adjustment', from: 'Add action of type'
    within('#action_fields') { click_button 'Add' }

    select2 'Tiered Percent', from: 'Calculator'
    within('#actions_container') { click_button 'Update' }

    within('#actions_container .settings') do
      expect(page).to have_content('Base Percent')
      expect(page).to have_content('Tiers')

      click_button 'Add'
    end

    fill_in 'Base Percent', with: 5

    within('.tier') do
      fill_in(class: 'js-base-input', with: '100')
      fill_in(class: 'js-value-input', with: '10')
    end
    within('#actions_container') { click_button 'Update' }

    first_action = promotion.actions.first
    expect(first_action.class).to eq Spree::Promotion::Actions::CreateAdjustment

    first_action_calculator = first_action.calculator
    expect(first_action_calculator.class).to eq Spree::Calculator::TieredPercent
    expect(first_action_calculator.preferred_base_percent).to eq 5
    expect(first_action_calculator.preferred_tiers).to eq Hash[100.0 => 10.0]
  end

  context 'with an existing tiered flat rate calculator' do
    let(:promotion) { create :promotion, :with_order_adjustment }

    before do
      action = promotion.actions.first

      action.calculator = Spree::Calculator::TieredFlatRate.new
      action.calculator.preferred_base_amount = 5
      action.calculator.preferred_tiers = Hash[100 => 10, 200 => 15, 300 => 20]
      action.calculator.save!

      visit spree.edit_admin_promotion_path(promotion)
    end

    it 'deleting a tier', js: true do
      within('.tier:nth-child(2)') do
        click_icon :delete
      end

      within('#actions_container') { click_button 'Update' }

      calculator = promotion.actions.first.calculator
      expect(calculator.preferred_tiers).to eq Hash[100.0 => 10.0, 300.0 => 20.0]
    end
  end
end
