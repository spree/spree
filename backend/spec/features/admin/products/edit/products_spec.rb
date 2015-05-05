# encoding: UTF-8
require 'spec_helper'

describe 'Product Details', type: :feature, js: true do
  stub_authorization!

  context 'editing a product' do
    it 'should list the product details' do
      create(:product, :name => 'Bún thịt nướng', :sku => 'A100',
              :description => 'lorem ipsum', :available_on => '2013-08-14 01:02:03')

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }

      click_link 'Details'

      expect(find('.content-header h1').text.strip).to eq('Products / Bún thịt nướng')
      expect(find('input#product_name').value).to eq('Bún thịt nướng')
      expect(find('input#product_slug').value).to eq('bun-th-t-n-ng')
      expect(find('textarea#product_description').text.strip).to eq('lorem ipsum')
      expect(find('input#product_price').value).to eq('19.99')
      expect(find('input#product_cost_price').value).to eq('17.00')
      expect(find('input#product_available_on').value).to eq("2013/08/14")
      expect(find('input#product_sku').value).to eq('A100')
    end

    it "should handle slug changes" do
      create(:product, name: 'Bún thịt nướng', sku: 'A100',
               description: 'lorem ipsum', available_on: '2011-01-01 01:01:01')

      visit spree.admin_products_path
      within('table.table tbody tr:nth-child(1)') do
        click_icon(:edit)
      end

      fill_in "product_slug", with: 'random-slug-value'
      click_button "Update"
      expect(page).to have_content("successfully updated!")

      fill_in "product_slug", with: 'a'
      click_button "Update"
      within('#product_slug_field') { expect(page).to have_content("is too short") }

      fill_in "product_slug", with: 'another-random-slug-value'
      click_button "Update"
      expect(page).to have_content("successfully updated!")
    end
  end

  # Regression test for #3385
  context "deleting a product" do
    it "is still able to find the master variant" do
      create(:product)

      visit spree.admin_products_path
      within_row(1) do
        accept_alert do
          click_icon :delete
        end
      end
      wait_for_ajax
    end
  end
end
