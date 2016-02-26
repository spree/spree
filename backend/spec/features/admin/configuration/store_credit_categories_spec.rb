require 'spec_helper'

describe "Store Credit Categories", type: :feature, js: true do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
  end

  context "admin visiting store credit categories list" do
    it "should display existing store credit categories" do
      create(:store_credit_category)
      click_link "Store Credit Categories"

      within_row(1) { expect(page).to have_content("Exchange") }
    end
  end

  context "admin creating a new store credit category" do
    before(:each) do
      click_link "Store Credit Categories"
      click_link "admin_new_store_credit_category_link"
    end

    it "should be able to create a new store credit category" do
      expect(page).to have_content("New Store Credit Category")
      fill_in "store_credit_category_name", with: "Return"
      click_button "Create"
      expect(page).to have_content("successfully created!")
    end

    it "should show validation errors if there are any" do
      click_button "Create"
      expect(page).to have_content("Name can't be blank")
    end
  end

  context "admin editing a store credit category" do
    it "should be able to update an existing store credit category" do
      create(:store_credit_category)
      click_link "Store Credit Categories"
      within_row(1) { click_icon :edit }
      fill_in "store_credit_category_name", with: "Return"
      click_button "Update"
      expect(page).to have_content("successfully updated!")
      expect(page).to have_content("Return")
    end
  end
end
