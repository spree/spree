require 'spec_helper'

feature 'Promotion with option value rule' do
  stub_authorization!

  given(:variant) { create :variant }
  given!(:product) { variant.product }
  given!(:option_value) { variant.option_values.first }

  given(:promotion) { create :promotion }

  background do
    visit spree.edit_admin_promotion_path(promotion)
  end

  scenario "adding an option value rule", js: true do
    select2 "Option Value(s)", from: "Add rule of type"
    within("#rule_fields") { click_button "Add" }

    within("#rules .promotion-block") do
      click_button "Add"

      expect(page.body).to have_content("Product")
      expect(page.body).to have_content("Option Values")
    end

    within('.promo-rule-option-value') do
      targetted_select2_search product.name, from: '.js-promo-rule-option-value-product-select'
      targetted_select2_search(
        option_value.name,
        from: '.js-promo-rule-option-value-option-values-select'
      )
    end

    within('#rules_container') { click_button "Update" }

    first_rule = promotion.rules(true).first
    expect(first_rule.class).to eq Spree::Promotion::Rules::OptionValue
    expect(first_rule.preferred_eligible_values).to eq Hash[product.id => [option_value.id]]
  end

  context "with an existing option value rule" do
    given(:variant1) { create :variant }
    given(:variant2) { create :variant }
    background do
      rule = Spree::Promotion::Rules::OptionValue.new
      rule.promotion = promotion
      rule.preferred_eligible_values = Hash[
        variant1.product_id => variant1.option_values.pluck(:id),
        variant2.product_id => variant2.option_values.pluck(:id)
      ]
      rule.save!

      visit spree.edit_admin_promotion_path(promotion)
    end

    scenario "deleting a product", js: true do
      within(".promo-rule-option-value:last-child") do
        find(".delete").click
      end

      within('#rule_fields') { click_button "Update" }

      first_rule = promotion.rules(true).first
      expect(first_rule.preferred_eligible_values).to eq(
        Hash[variant1.product_id => variant1.option_values.pluck(:id)]
      )
    end
  end
end
