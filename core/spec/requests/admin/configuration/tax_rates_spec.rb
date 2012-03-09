require 'spec_helper'

describe "Tax Rates" do
  let!(:tax_rate) { Factory(:tax_rate, :calculator => stub_model(Spree::Calculator)) }

  before do
    sign_in_as! Factory(:admin_user)
    visit spree.admin_path
    click_link "Configuration"
  end

  # Regression test for #535
  it "can see a tax rate in the list if the tax category has been deleted" do
    tax_rate.tax_category.mark_deleted!
    lambda { click_link "Tax Rates" }.should_not raise_error
    within("table tbody td:nth-child(2)") do
      page.should have_content("N/A")
    end
  end
end
