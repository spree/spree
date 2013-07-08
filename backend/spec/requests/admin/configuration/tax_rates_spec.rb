require 'spec_helper'

describe "Tax Rates" do
  stub_authorization!

  let!(:tax_rate) { create(:tax_rate, :calculator => stub_model(Spree::Calculator)) }

  before do
    visit spree.admin_path
    click_link "Configuration"
  end

  # Regression test for #535
  it "can see a tax rate in the list if the tax category has been deleted" do
    tax_rate.tax_category.update_column(:deleted_at, Time.now)
    lambda { click_link "Tax Rates" }.should_not raise_error
    within("table tbody td:nth-child(3)") do
      page.should have_content("N/A")
    end
  end

  # Regression test for #1422
  it "can create a new tax rate" do
    click_link "Tax Rates"
    click_link "New Tax Rate"
    fill_in "Rate", :with => "0.05"
    click_button "Create"
    page.should have_content("Tax Rate has been successfully created!")
  end
end
