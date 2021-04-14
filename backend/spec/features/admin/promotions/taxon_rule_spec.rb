require 'spec_helper'

describe 'Promotion with taxon rule', type: :feature do
  stub_authorization!

  let!(:taxons) { create_list(:taxon, 2) }
  let!(:taxon1) { taxons.first  }
  let!(:taxon2) { taxons.second }

  let!(:promotion) { create :promotion }

  before do
    visit spree.edit_admin_promotion_path(promotion)
  end

  context 'when there are no taxon rules' do
    it 'adding a taxon rule', js: true do
      select2 'Taxon(s)', from: 'Add rule of type'
      within('#rule_fields') { click_button 'Add' }

      within('.promotion_rule') do
        select2 taxon1.name, css: '.taxons_rule_taxons', search: true
        select2 taxon2.name, css: '.taxons_rule_taxons', search: true
      end

      within('#rules_container') { click_button 'Update' }

      first_rule = promotion.rules.reload.first
      expect(first_rule.class).to eq Spree::Promotion::Rules::Taxon
      expect(first_rule.taxons).to contain_exactly(taxon1, taxon2)
    end
  end

  context 'when there is a taxon rule' do
    before do
      rule = Spree::Promotion::Rules::Taxon.new(promotion: promotion)
      rule.save!
      rule.update!(taxons: taxons)

      visit spree.edit_admin_promotion_path(promotion)
    end

    it 'displays taxon names', js: true do
      within('.promotion_rule') do
        expect(page).to have_content(taxon1.name)
        expect(page).to have_content(taxon2.name)
      end
    end
  end
end
