require 'spec_helper'

describe "Cancelling + Resuming", :type => :feature do
  stub_authorization!

  let(:order) do 
    order = create(:order)
    order.update_columns({
      :state => 'complete',
      :completed_at => Time.now
    })
    order
  end

  it "can cancel an order" do
    visit spree.edit_admin_order_path(order.number)
    click_button 'cancel'
    within(".additional-info") do
      within(".state") do
        expect(page).to have_content("canceled")
      end
    end
  end

  context "with a canceled order" do
    before do
      order.update_column(:state, 'canceled')
    end

    it "can resume an order" do
      visit spree.edit_admin_order_path(order.number)
      click_button 'resume'
      within(".additional-info") do
        within(".state") do
          expect(page).to have_content("resumed")
        end
      end
    end
  end
end