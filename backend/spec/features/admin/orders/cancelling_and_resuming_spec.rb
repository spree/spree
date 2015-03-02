require 'spec_helper'

describe "Cancelling + Resuming", :type => :feature do

  stub_authorization!

  let(:user) { double(id: 123, has_spree_role?: true, spree_api_key: 'fake') }

  before do
    allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(user)
  end

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
    click_button 'Cancel'
    within(".additional-info") do
      within(".state") do
        expect(page).to have_content("canceled")
      end
    end
  end

  context "with a cancelled order" do
    before do
      order.update_column(:state, 'canceled')
    end

    it "can resume an order" do
      visit spree.edit_admin_order_path(order.number)
      click_button 'Resume'
      within(".additional-info") do
        within(".state") do
          expect(page).to have_content("resumed")
        end
      end
    end
  end
end
