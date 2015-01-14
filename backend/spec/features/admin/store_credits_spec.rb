require 'spec_helper'

describe "Store credits admin" do
  stub_authorization!
  let!(:admin_user)   { create(:admin_user) }
  let!(:store_credit) { create(:store_credit) }

  describe "visiting the store credits page" do
    before do
      visit spree.admin_path
      click_link "Users"
    end

    it "should be on the store credits page" do
      click_link store_credit.user.email
      click_link "Store Credit"
      page.current_path.should eq spree.admin_user_store_credits_path(store_credit.user)

      store_credit_table = page.find(".twelve.columns > table")
      store_credit_table.all('tr').count.should eq 1
      store_credit_table.should have_content(Spree::Money.new(store_credit.amount).to_s)
      store_credit_table.should have_content(Spree::Money.new(store_credit.amount_used).to_s)
      store_credit_table.should have_content(store_credit.category_name)
      store_credit_table.should have_content(store_credit.created_by_email)
    end
  end

  describe "creating store credit" do
    before do
      visit spree.admin_path
      click_link "Users"
      click_link store_credit.user.email
      click_link "Store Credit"
      Spree::Admin::StoreCreditsController.any_instance.stub(try_spree_current_user: admin_user)
    end

    it "should create store credit and associate it with the user" do
      click_link "Add store credit"
      page.fill_in "store_credit_amount", with: "102.00"
      select "Exchange", from: "store_credit_category_id"
      click_button "Create"

      page.current_path.should eq spree.admin_user_store_credits_path(store_credit.user)
      store_credit_table = page.find(".twelve.columns > table")
      store_credit_table.all('tr').count.should eq 2
      Spree::StoreCredit.count.should eq 2
    end
  end

  describe "updating store credit" do
    let(:updated_amount) { "99.0" }

    before do
      visit spree.admin_path
      click_link "Users"
      click_link store_credit.user.email
      click_link "Store Credit"
      Spree::Admin::StoreCreditsController.any_instance.stub(try_spree_current_user: admin_user)
    end

    it "should create store credit and associate it with the user" do
      click_link "Edit"
      page.fill_in "store_credit_amount", with: updated_amount
      click_button "Update"

      page.current_path.should eq spree.admin_user_store_credits_path(store_credit.user)
      store_credit_table = page.find(".twelve.columns > table")
      store_credit_table.should have_content(Spree::Money.new(updated_amount).to_s)
      store_credit.reload.amount.to_f.should eq updated_amount.to_f
    end
  end

end
