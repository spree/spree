require 'spec_helper'

describe "Homepage" do

  context 'as admin user' do
    stub_authorization!

    context "visiting the homepage" do
      before(:each) do
        visit spree.admin_path
      end

      it "should have the header text 'Listing Orders'" do
        within('h1') { page.should have_content("Listing Orders") }
      end

      it "should have a link to overview" do
        within(:xpath, ".//figure[@data-hook='logo-wrapper']") { page.find(:xpath, "a[@href='/admin']") }
      end

      it "should have a link to orders" do
        page.find_link("Orders")['/admin/orders']
      end

      it "should have a link to products" do
        page.find_link("Products")['/admin/products']
      end

      it "should have a link to reports" do
        page.find_link("Reports")['/admin/reports']
      end

      it "should have a link to configuration" do
        page.find_link("Configuration")['/admin/configurations']
      end
    end

    context "visiting the products tab" do
      before(:each) do
        visit spree.admin_products_path
      end

      it "should have a link to products" do
        within('#sub-menu') { page.find_link("Products")['/admin/products'] }
      end

      it "should have a link to option types" do
        within('#sub-menu') { page.find_link("Option Types")['/admin/option_types'] }
      end

      it "should have a link to properties" do
        within('#sub-menu') { page.find_link("Properties")['/admin/properties'] }
      end

      it "should have a link to prototypes" do
        within('#sub-menu') { page.find_link("Prototypes")['/admin/prototypes'] }
      end
    end
  end

  context 'as fakedispatch user' do
    custom_authorization! do |user|
      can [:admin, :edit, :index, :read], Spree::Order
    end

    it 'should only display tabs fakedispatch has access to' do
      visit spree.admin_path
      page.should have_link('Orders')
      page.should_not have_link('Products')
      page.should_not have_link('Promotions')
      page.should_not have_link('Reports')
      page.should_not have_link('Configuration')
    end
  end

end
