require 'spec_helper'

describe "Homepage" do
  stub_authorization!

  context "visiting the homepage" do
    before(:each) do
      visit spree.admin_path
    end

    it "should have the header text 'Administration'" do
      within(:css, 'h1') { page.should have_content("Administration") }
    end

    it "should have a link to overview" do
      page.find_link("Overview")['/admin']
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
      within(:css, '#sub-menu') { page.find_link("Products")['/admin/products'] }
    end

    it "should have a link to option types" do
      within(:css, '#sub-menu') { page.find_link("Option Types")['/admin/option_types'] }
    end

    it "should have a link to properties" do
      within(:css, '#sub-menu') { page.find_link("Properties")['/admin/properties'] }
    end

    it "should have a link to prototypes" do
      within(:css, '#sub-menu') { page.find_link("Prototypes")['/admin/prototypes'] }
    end

  end
end
