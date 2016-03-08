require 'spec_helper'

describe "Tax Rates", type: :feature do
  stub_authorization!

  let!(:tax_rate) { create(:tax_rate, calculator: stub_model(Spree::Calculator)) }

  before { visit spree.admin_tax_rates_path }

  it 'does not have a new tax rate' do
    expect(page).not_to have_content('New Tax Rate 1')
  end

  # Regression test for #1422
  it "can create a new tax rate" do
    click_link "New Tax Rate"
    fill_in "Rate", with: "0.05"
    fill_in "Name", with: "New Tax Rate 1"
    click_button "Create"
    check_property_row_count(2)
    expect(page).to have_content("New Tax Rate 1")
  end

  def check_property_row_count(expected_row_count)
    expect(page).to have_css("tbody#tax_rates")
    expect(all("tbody#tax_rates tr").count).to eq(expected_row_count)
  end
end
