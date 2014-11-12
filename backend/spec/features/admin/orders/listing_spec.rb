require 'spec_helper'

describe "Orders Listing", :type => :feature do
  stub_authorization!

  let!(:promotion) { create(:promotion_with_item_adjustment) }

  before(:each) do
    allow_any_instance_of(Spree::OrderInventory).to receive(:add_to_shipment)
    @order1 = create(:order_with_line_items, created_at: 1.day.from_now, completed_at: 1.day.from_now, considered_risky: true, number: "R100")
    @order2 = create(:order, created_at: 1.day.ago, completed_at: 1.day.ago, number: "R200")
    visit spree.admin_path
  end

  context "listing orders" do
    before(:each) do
      click_link "Orders"
    end

    it "should list existing orders" do
      within_row(1) do
        expect(column_text(2)).to eq "R100"
        expect(find("td:nth-child(3)")).to have_css '.considered_risky'
        expect(column_text(4)).to eq "cart"
      end

      within_row(2) do
        expect(column_text(2)).to eq "R200"
        expect(find("td:nth-child(3)")).to have_css '.considered_safe'
      end
    end

    it "should be able to sort the orders listing" do
      # default is completed_at desc
      within_row(1) { expect(page).to have_content("R100") }
      within_row(2) { expect(page).to have_content("R200") }

      click_link "Completed At"

      # Completed at desc
      within_row(1) { expect(page).to have_content("R200") }
      within_row(2) { expect(page).to have_content("R100") }

      within('table#listing_orders thead') { click_link "Number" }

      # number asc
      within_row(1) { expect(page).to have_content("R100") }
      within_row(2) { expect(page).to have_content("R200") }
    end
  end

  context "searching orders" do
    before(:each) do
      click_link "Orders"
    end

    it "should be able to search orders" do
      fill_in "q_number_cont", :with => "R200"
      click_icon :search
      within_row(1) do
        expect(page).to have_content("R200")
      end

      # Ensure that the other order doesn't show up
      within("table#listing_orders") { expect(page).not_to have_content("R100") }
    end

    it "should be able to filter risky orders" do
      # Check risky and filter
      check "q_considered_risky_eq"
      click_button "Filter Results"

      # Insure checkbox still checked
      expect(find("#q_considered_risky_eq")).to be_checked
      # Insure we have the risky order, R100
      within_row(1) do
        expect(page).to have_content("R100")
      end
      # Insure the non risky order is not present
      expect(page).not_to have_content("R200")
    end

    it "should be able to filter risky orders" do
      # Check risky and filter
      check "q_considered_risky_eq"
      click_button "Filter Results"

      # Insure checkbox still checked
      find("#q_considered_risky_eq").should be_checked
      # Insure we have the risky order, R100
      within_row(1) do
        page.should have_content("R100")
      end
      # Insure the non risky order is not present
      page.should_not have_content("R200")
    end

    it "should be able to filter on variant_id" do
      # Insure we have the SKU in the options
      expect(find('#q_line_items_variant_id_in').all('option').collect(&:text)).to include(@order1.line_items.first.variant.sku)

      # Select and filter
      find('#q_line_items_variant_id_in').find(:xpath, 'option[2]').select_option
      click_button "Filter Results"

      within_row(1) do
        page.should have_content(@order1.number)
      end

      page.should_not have_content(@order2.number)
    end

    context "when pagination is really short" do
      before do
        @old_per_page = Spree::Config[:orders_per_page]
        Spree::Config[:orders_per_page] = 1
      end

      after do
        Spree::Config[:orders_per_page] = @old_per_page
      end

      # Regression test for #4004
      it "should be able to go from page to page for incomplete orders" do
        10.times { Spree::Order.create :email => "incomplete@example.com" }
        uncheck "q_completed_at_not_null"
        click_button "Filter Results"
        within(".pagination") do
          click_link "2"
        end
        expect(page).to have_content("incomplete@example.com")
        expect(find("#q_completed_at_not_null")).not_to be_checked
      end
    end

    it "should be able to search orders using only completed at input" do
      fill_in "q_created_at_gt", :with => Date.current
      click_icon :search
      within_row(1) { expect(page).to have_content("R100") }

      # Ensure that the other order doesn't show up
      within("table#listing_orders") { expect(page).not_to have_content("R200") }
    end

    context "filter on promotions", :js => true do
      before(:each) do
        @order1.promotions << promotion
        @order1.save
        click_link "Orders"
      end

      it "only shows the orders with the selected promotion" do
        select2 promotion.name, :from => "Promotion"
        click_icon :search
        within_row(1) { expect(page).to have_content("R100") }
        within("table#listing_orders") { expect(page).not_to have_content("R200") }
      end
    end

  end
end
