require 'spec_helper'

describe "Adjustments", type: :feature do
  stub_authorization!

  let!(:order) { create(:completed_order_with_totals, line_items_count: 5) }
  let!(:line_item) do
    line_item = order.line_items.first
    # so we can be sure of a determinate price in our assertions
    line_item.update_column(:price, 10)
    line_item
  end

  let!(:tax_adjustment) do
    create(:tax_adjustment,
      :adjustable => line_item,
      :state => 'closed',
      :order => order,
      :label => "VAT 5%",
      :amount => 10)
  end

  let!(:adjustment) { order.adjustments.create!(order: order, label: 'Rebate', amount: 10) }

  before(:each) do
    # To ensure the order totals are correct
    order.update_totals
    order.persist_totals

    visit spree.admin_orders_path
    within_row(1) { click_on order.number }
    click_on "Adjustments"
  end

  after :each do
    order.reload.all_adjustments.each do |adjustment|
      expect(adjustment.order_id).to equal(order.id)
    end
  end

  context "admin managing adjustments" do
    it "should display the correct values for existing order adjustments" do
      within_row(1) do
        expect(column_text(2)).to eq("VAT 5%")
        expect(column_text(3)).to eq("$10.00")
      end
    end

    it "only shows eligible adjustments" do
      expect(page).not_to have_content("ineligible")
    end
  end

  context "admin creating a new adjustment" do
    before(:each) do
      click_link "New Adjustment"
    end

    context "successfully" do
      it "should create a new adjustment" do
        fill_in "adjustment_amount", with: "10"
        fill_in "adjustment_label", with: "rebate"
        click_button "Continue"
        expect(page).to have_content("successfully created!")
        expect(page).to have_content("Total: $180.00")
      end
    end

    context "with validation errors" do
      it "should not create a new adjustment" do
        fill_in "adjustment_amount", with: ""
        fill_in "adjustment_label", with: ""
        click_button "Continue"
        expect(page).to have_content("Label can't be blank")
        expect(page).to have_content("Amount is not a number")
      end
    end
  end

  context "admin editing an adjustment", js: true do

    before(:each) do
      within_row(2) { click_icon :edit }
    end

    context "successfully" do
      it "should update the adjustment" do
        fill_in "adjustment_amount", with: "99"
        fill_in "adjustment_label", with: "rebate 99"
        click_button "Continue"
        expect(page).to have_content("successfully updated!")
        expect(page).to have_content("rebate 99")
        within(".adjustments") do
          expect(page).to have_content("$99.00")
        end

        expect(page).to have_content("Total: $259.00")
      end
    end

    context "with validation errors" do
      it "should not update the adjustment" do
        fill_in "adjustment_amount", with: ""
        fill_in "adjustment_label", with: ""
        click_button "Continue"
        expect(page).to have_content("Label can't be blank")
        expect(page).to have_content("Amount is not a number")
      end
    end
  end

  context "deleting an adjustment" do
    it "should not be possible if adjustment is closed" do
      within_row(1) do
        expect(page).not_to have_css('.fa-delete')
      end
    end

    it "should update the total", js: true do
      accept_alert do
        within_row(2) do
          click_icon(:delete)
        end
      end

      expect(page).to have_content(/Total: ?\$170\.00/)
    end
  end
end
