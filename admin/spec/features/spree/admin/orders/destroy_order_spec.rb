require 'spec_helper'

describe 'Destroy Order Spec', type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:order) { create(:order, store: store) }

  context 'draft order' do
    it 'can be destroyed' do
      visit spree.edit_admin_order_path(order)
      within('#page_actions_dropdown') do
        click_on 'more-actions-link'
        accept_confirm do
          click_on 'Delete'
        end
      end

      expect(page).to have_content('Order has been successfully removed!')
      expect(Spree::Order.count).to eq 0
    end
  end

  context 'completed order' do
    let(:order) { create(:shipped_order, store: store) }

    it 'cannot be destroyed' do
      visit spree.edit_admin_order_path(order)
      within('#page_actions_dropdown') do
        expect(page).not_to have_content('Delete')
      end
    end
  end
end
