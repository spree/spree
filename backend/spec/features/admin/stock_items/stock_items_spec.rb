require 'spec_helper'

describe "Stock Items", type: :feature do
  stub_authorization!

  let!(:stock_location) { create(:stock_location, name: 'Stock Location1') }
  let!(:stock_location1) { create(:stock_location, name: 'Stock Location2') }
  let!(:product) { create(:product) }
  let!(:product1) { create(:product) }
  let!(:variant) { product.master }
  let!(:variant1) { product1.master }
  let!(:stock_item) { variant.stock_items.find_by(stock_location_id: stock_location.id) }
  let!(:stock_item1) { variant.stock_items.find_by(stock_location_id: stock_location1.id) }
  let!(:stock_item2) { variant1.stock_items.find_by(stock_location_id: stock_location.id) }

  before do
    stock_location1.stock_items.where(variant_id: variant1.id).destroy_all
    visit spree.admin_stock_items_path
  end

  describe 'listing', js: true do
    describe 'list stock items with respect to the stock location' do
      context 'stocks for stock_location' do
        it { expect(page).to have_content(variant.sku) }
        it { expect(page).to have_content(variant1.sku) }
      end

      context 'stocks for stock_location1' do
        before do
          select2_search(stock_location1.name, from: 'Select stock location')
          wait_for_ajax
        end
        it { expect(page).to have_content(variant.sku) }
        it { expect(page).not_to have_content(variant1.sku) }
      end
    end

    it 'has delete link' do
      expect(page).to have_css('.icon-delete')
    end
  end

  describe 'searching' do
    def search(**options)
      click_on 'Filter'
      options.each do |field, value|
        fill_in field.to_s, with: value
      end
      click_on 'Search'
    end

    context 'results present' do
      context 'search on name' do
        before do
          search(q_variant_product_name_cont: variant.name)
        end

        it { expect(page).to have_content(variant.name) }
        it { expect(page).not_to have_content(variant1.name) }
      end

      context 'search on sku' do
        before do
          search(q_variant_sku_cont: variant1.sku)
        end

        it { expect(page).to have_content(variant1.name) }
        it { expect(page).not_to have_content(variant.name) }
      end

      context 'search on sku and name both' do
        before do
          search(q_variant_sku_cont: variant.sku, q_variant_product_name_cont: variant.name)
        end

        it { expect(page).not_to have_content(variant1.name) }
        it { expect(page).to have_content(variant.name) }
      end
    end

    context 'result not present' do
      before do
        search(q_variant_sku_cont: variant.sku, q_variant_product_name_cont: variant1.name)
      end

      it { expect(page).not_to have_content(variant.name) }
      it { expect(page).not_to have_content(variant1.name) }
      it { expect(page).to have_content('No Stock item found') }
    end
  end

  describe 'quantity update', js: true do
    context 'it is increased' do
      before do
        within_row(1) do
          fill_in 'number_spinner', with: 20
          click_link 'Save'
        end
        wait_for_ajax
      end
      it "stock item's current count_on_hand to change to 20" do
        within_row(1) do
          expect(page).to have_content(20)
        end
      end
      it 'page has a success message' do
        expect(page).to have_content(Spree.t(:successfully_created,
                                             resource: Spree::StockMovement.new.class.model_name.human))
      end
    end

    context 'it is decreased' do
      context 'backorderable' do
        before do
          within_row(1) do
            fill_in 'number_spinner', with: -10
            click_link 'Save'
          end
          wait_for_ajax
        end
        it "stock item's current count_on_hand to change to -10" do
          within_row(1) do
            expect(page).to have_content(-10)
          end
        end
        it 'page has a success message' do
          expect(page).to have_content(Spree.t(:successfully_created,
                                               resource: Spree::StockMovement.new.class.model_name.human))
        end
      end

      context 'not backorderable' do
        before do
          variant1.stock_items.update_all(backorderable: false)
          within_row(2) do
            fill_in 'number_spinner', with: -10
            click_link 'Save'
          end
          wait_for_ajax
        end
        it "stock item's current count_on_hand does not change to -10" do
          within_row(2) do
            expect(page).not_to have_content(-10)
          end
        end
        it 'page has a failure message' do
          expect(page).to have_content('Count on hand must be greater than or equal to 0')
        end
      end
    end
  end

  describe 'delete stock_item', js: true do
    before do
      within_row(1) do
        accept_alert do
          click_icon :delete
        end
      end
      wait_for_ajax
    end
    it { expect(page).to have_content(variant1.sku) }
    it { expect(page).not_to have_content(variant.sku) }
  end
end
