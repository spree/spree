require 'spec_helper'

describe "Stock Management" do
  stub_authorization!

  context "as admin user" do
    before(:each) do
      visit spree.admin_path
    end

    context "given a product with a variant and a stock location" do
      before do
        create(:stock_location, name: 'Default')
        @product = create(:product, name: 'apache baseball cap', price: 10)
        v = @product.variants.create!(sku: 'FOOBAR')
        v.stock_items.first.update_column(:count_on_hand, 10)

        click_link "Products"
        within_row(1) do
          click_icon :edit
        end
      end

      it "can view count on hand for the variant" do
        click_link "Stock Management"

        within_row(1) do
          page.should have_content('Count On Hand')
          within(:css, '.stock_location_info') do
            column_text(2).should have_content('10')
          end
        end
      end

      it "can toggle backorderable for a variant's stock item", js: true do
        click_link "Stock Management"

        backorderable = find "#stock_item_backorderable"
        backorderable.should be_checked

        backorderable.set(false)
        visit current_path

        backorderable.should_not be_checked
      end

      it "can create a new stock movement", js: true do
        click_link "Stock Management"

        fill_in "stock_movement_quantity", with: 5
        select2 "default", from: "Stock Location"
        click_button "Add Stock"

        page.should have_content('successfully created')

        within(:css, '.stock_location_info table') do
          column_text(2).should eq '15'
        end
      end

      it "can create a new negative stock movement", js: true do
        click_link "Stock Management"

        fill_in "stock_movement_quantity", with: -5
        select2 "default", from: "Stock Location"
        click_button "Add Stock"

        page.should have_content('successfully created')

        within(:css, '.stock_location_info table') do
          column_text(2).should eq '5'
        end
      end

      it "can create a new negative stock movement", js: true do
        click_link "Stock Management"

        fill_in "stock_movement_quantity", with: -5
        select2 "default", from: "Stock Location"
        click_button "Add Stock"

        page.should have_content('successfully created')

        within(:css, '.stock_location_info table') do
          column_text(2).should eq '5'
        end
      end

      context "with multiple variants" do
        before do
          v = @product.variants.create!(sku: 'SPREEC')
          v.stock_items.first.update_column(:count_on_hand, 30)
        end

        it "can create a new stock movement for the specified variant", js: true do
          click_link "Stock Management"
          fill_in "stock_movement_quantity", with: 10
          select2 "SPREEC", from: "Variant"
          click_button "Add Stock"

          page.should have_content('successfully created')

          within_row(2) do
            page.should have_content("SPREEC")
            within(:css, '.stock_location_info table') do
              column_text(2).should eq '40'
            end
          end
        end
      end
    end
  end
end
