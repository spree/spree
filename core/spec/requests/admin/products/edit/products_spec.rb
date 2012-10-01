# encoding: UTF-8
require 'spec_helper'

describe 'Product Details' do
  stub_authorization!

  context 'editing a product' do
    let(:available_on) { Time.now }
    it 'should list the product details' do
      create(:product, :name => 'Bún thịt nướng', :permalink => 'bun-thit-nuong', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => available_on, :count_on_hand => 10)

      visit spree.admin_path
      click_link 'Products'
      within('table.index tbody tr:nth-child(1)') do
        click_icon(:edit)
      end

      click_link 'Product Details'

      find('.page-title').text.strip.should == 'Editing Product “Bún thịt nướng”'
      find('input#product_name').value.should == 'Bún thịt nướng'
      find('input#product_permalink').value.should == 'bun-thit-nuong'
      find('textarea#product_description').text.strip.should == 'lorem ipsum'
      find('input#product_price').value.should == '19.99'
      find('input#product_cost_price').value.should == '17.00'
      find('input#product_available_on').value.should_not be_blank
      find('input#product_sku').value.should == 'A100'
    end

    it "should handle permalink changes" do
      create(:product, :name => 'Bún thịt nướng', :permalink => 'bun-thit-nuong', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => '2011-01-01 01:01:01', :count_on_hand => 10)

      visit spree.admin_path
      click_link 'Products'
      within('table.index tbody tr:nth-child(1)') do
        click_icon(:edit)
      end

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
