require 'spec_helper'

describe "Product Groups" do
  before(:each) do
    sign_in_as!(Factory(:admin_user))
    visit spree.admin_path
    click_link "Products"
  end

  context "listing product groups" do
    it "should display existing product groups" do
      Factory(:product_group)
      Factory(:product_group, :name => 'casual')

      click_link "Product Groups"
      find('table#listing_product_groups tbody tr:nth-child(1) td:nth-child(1)').text.should == 'casual'
      find('table#listing_product_groups tbody tr:nth-child(2) td:nth-child(1)').text.should == 'sports'
    end
  end

  context "creating a new product group" do
    it "should allow an admin to create a new product group", :js => true do
      click_link "Product Groups"
      click_on "New Product Group"
      within('#content') { page.should have_content("Product Group") }
      fill_in "product_group_name", :with => "male shirts"
      click_button "Create"
      page.should have_content("successfully created!")
    end
  end

  context "updating an existing product group" do
    it "should allow an admin to update an existing product group", :js => true do
      Factory(:product_group)
      click_link "Product Groups"
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      fill_in "product_group_name", :with => "most popular rails items 99"
      click_button "Update"
      page.should have_content("successfully updated!")
      click_link "Product Groups"
      page.should have_content("most popular rails items 99")
    end

    it "should handle permalink changes" do
      Factory(:product_group)
      click_link "Product Groups"
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }

      fill_in "product_group_permalink", :with => 'random-permalink-value'
      click_button "Update"
      page.should have_content("successfully updated!")

      fill_in "product_group_permalink", :with => ''
      click_button "Update"
      within('#product_group_permalink_field') { page.should have_content("can't be blank") }

      click_button "Update"
      within('#product_group_permalink_field') { page.should have_content("can't be blank") }

      fill_in "product_group_permalink", :with => 'another-random-permalink-value'
      click_button "Update"
      page.should have_content("successfully updated!")

    end
  end

  context "scoping", :js => true do
    before(:each) do
      Factory(:product_group)
      click_link "Product Groups"
    end

    it "by product name" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Product name have following", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Product name have following") }
    end

    it "by product name or meta keywords" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Product name or meta keywords have following", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Product name or meta keywords have following") }
    end

    it "by product name or description" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Product name or description have following", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Product name or description have following") }
    end

    it "with ids" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Products with IDs", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Products with IDs") }
    end

    it "with option and value" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "With option and value", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("With option and value") }
    end

    it "with property" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "With property", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("With property") }
    end

    it "with property value" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "With property value", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("With property value") }
    end

    it "with value" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "With value", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("With value") }
    end

    it "with option" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "With option", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("With option") }
    end

    it "price between" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Price between", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Price between") }
    end

    it "master price lesser or equal to" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Master price lesser or equal to", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Master price lesser or equal to") }
    end

    it "master price greater or equal to" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "Master price greater or equal to", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("Master price greater or equal to") }
    end

    it "in taxons and all their descendants" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "In taxons and all their descendants", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("In taxons and all their descendants") }
    end

    it "in taxon(without descendants)" do
      within('table#listing_product_groups tbody tr:nth-child(1)') { click_link "Edit" }
      select "In Taxon(without descendants)", :from => "product_scope_name"
      click_button "Add"
      within('table#product_scopes') { page.should have_content("In Taxon(without descendants)") }
    end
  end
end
