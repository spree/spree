# encoding: UTF-8
require 'spec_helper'

describe 'Product Details' do
  context 'editing a product' do
    it 'should list the product details' do
      Factory(:product, :name => 'Bún thịt nướng', :permalink => 'bun-thit-nuong', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => '2011-01-01 01:01:01', :count_on_hand => 10)

      sign_in_as!(Factory(:admin_user))
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
        find('input#product_available_on').value.should == '2011-01-01 01:01:01.000000'
        find('input#product_sku').value.should == 'A100'
      end

    end
  end
end
