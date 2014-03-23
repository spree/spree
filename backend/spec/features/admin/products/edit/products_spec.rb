# encoding: UTF-8
require 'spec_helper'

describe 'Product Details' do
  stub_authorization!

  context 'editing a product' do
    it 'should list the product details' do
      create(:product, :name => 'Bún thịt nướng', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => '2013-08-14 01:02:03')

      visit spree.admin_path
      click_link 'Products'
      within_row(1) { click_icon :edit }

      click_link 'Product Details'

      find('.page-title').text.strip.should == 'Editing Product “Bún thịt nướng”'
      find('input#product_name').value.should == 'Bún thịt nướng'
      find('input#product_slug').value.should == 'bun-th-t-n-ng'
      find('textarea#product_description').text.strip.should == 'lorem ipsum'
      find('input#product_price').value.should == '19.99'
      find('input#product_cost_price').value.should == '17.00'
      find('input#product_available_on').value.should == "2013/08/14"
      find('input#product_sku').value.should == 'A100'
    end

    it "should handle slug changes" do
      create(:product, :name => 'Bún thịt nướng', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => '2011-01-01 01:01:01')

      visit spree.admin_path
      click_link 'Products'
      within('table.index tbody tr:nth-child(1)') do
        click_icon(:edit)
      end

      fill_in "product_slug", :with => 'random-slug-value'
      click_button "Update"
      page.should have_content("successfully updated!")

      fill_in "product_slug", :with => ''
      click_button "Update"
      within('#product_slug_field') { page.should have_content("is too short") }

      fill_in "product_slug", :with => 'another-random-slug-value'
      click_button "Update"
      page.should have_content("successfully updated!")
    end
  end

  # Regression test for #3385
  context "deleting a product", :js => true do
    it "is still able to find the master variant" do
      create(:product)

      visit spree.admin_products_path
      within_row(1) do
        accept_alert do
          click_icon :trash
        end
      end
      wait_for_ajax
    end
  end
end
