require 'spec_helper'

describe 'Cancelling + Resuming', type: :feature do
  stub_authorization!

  let(:user) { double(id: 123, has_spree_role?: true, spree_api_key: 'fake', email: 'spree@example.com') }
  let(:order) do
    order = create(:order)
    order.update_columns(state: 'complete', completed_at: Time.current)
    order
  end

  before do
    allow_any_instance_of(Spree::Admin::BaseController).to receive(:try_spree_current_user).and_return(user)
  end

  it 'can cancel an order' do
    visit spree.edit_admin_order_path(order.number)
    within find('#contentHeader') do
      click_button 'Cancel'
    end

    expect(page).to have_css('.additional-info .state', text: 'canceled')
  end

  context 'with a cancelled order' do
    before do
      order.update_column(:state, 'canceled')
    end

    it 'can resume an order' do
      visit spree.edit_admin_order_path(order.number)
      within find('#contentHeader') do
        click_button 'Resume'
      end
      
      expect(page).to have_css('.additional-info .state', text: 'resumed')
    end
  end
end
