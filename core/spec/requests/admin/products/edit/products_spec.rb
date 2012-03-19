# encoding: UTF-8
require 'spec_helper'

describe 'Product Details' do
  context 'editing a product' do
    let(:available_on) { Time.now }
    it 'should list the product details' do
      Factory(:product, :name => 'Bún thịt nướng', :permalink => 'bun-thit-nuong', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => available_on, :count_on_hand => 10)

      visit spree.admin_path
      click_link 'Products'
      within('table.index tr:nth-child(2)') { click_link 'Edit' }
      click_link 'Product Details'

      within('#content') do
        find('h1').text.should == 'Editing Product “Bún thịt nướng”'
        find('input#product_name').value.should == 'Bún thịt nướng'
        find('input#product_permalink').value.should == 'bun-thit-nuong'
        find('textarea#product_description').text.should == 'lorem ipsum'
        find('input#product_price').value.should == '19.99'
        find('input#product_cost_price').value.should == '17.00'
        find('input#product_available_on').value.should_not be_blank
        find('input#product_sku').value.should == 'A100'
      end

    end

    it "should handle permalink changes" do
      Factory(:product, :name => 'Bún thịt nướng', :permalink => 'bun-thit-nuong', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => '2011-01-01 01:01:01', :count_on_hand => 10)

      visit spree.admin_path
      click_link 'Products'
      within('table.index tr:nth-child(2)') { click_link 'Edit' }

      fill_in "product_permalink", :with => 'random-permalink-value'
      click_button "Update"
      page.should have_content("successfully updated!")

      fill_in "product_permalink", :with => ''
      click_button "Update"
      within('#product_permalink_field') { page.should have_content("can't be blank") }

      click_button "Update"
      within('#product_permalink_field') { page.should have_content("can't be blank") }

      fill_in "product_permalink", :with => 'another-random-permalink-value'
      click_button "Update"
      page.should have_content("successfully updated!")

    end
  end
end
