require 'spec_helper'

describe 'Return Authorizations', type: :feature, js: true, use_transaction: true do
  stub_authorization!

  let!(:shipped_order)               { create(:shipped_order, line_items_price: 19.99) }
  let!(:return_authorization_reason) { create(:return_authorization_reason) }
  let!(:reimbursement_type)          { create(:reimbursement_type) }
  let!(:stock_location)              { Spree::StockLocation.first }
  let!(:price)                       { '$19.99' }

  before do
    visit spree.new_admin_order_return_authorization_path(shipped_order)
    find(:css, 'input.add-item').set(true)

    find('div#s2id_return_authorization_return_items_attributes_0_preferred_reimbursement_type_id').click
    find('div.select2-result-label').click

    find('div#s2id_return_authorization_stock_location_id').click
    find('li', text: stock_location.name).click

    find('div#s2id_return_authorization_return_authorization_reason_id').click
    find('div.select2-result-label', text: return_authorization_reason.name).click
  end

  describe 'partial refunds' do
    context 'when pre tax amount' do
      context 'is lower than variant price' do
        it 'creates return authorization with that amount' do
          fill_in_pre_tax_amount('15.30')
          click_button 'Create'
  
          expect(page).to have_current_path(spree.admin_order_return_authorizations_path(shipped_order))
          expect(page).to have_css('tr', text: '$15.30')
        end
      end

      context 'is greater than variant price' do
        it 'creates return authorization with variant price' do
          fill_in_pre_tax_amount('20')
          wait_for_ajax
          click_button 'Create'

          expect(page).to have_current_path(spree.admin_order_return_authorizations_path(shipped_order))
          expect(page).to have_css('tr', text: price)
        end
      end

      context 'is a string' do
        it 'creates return authorization with variant price' do
          fill_in_pre_tax_amount('abc')
          wait_for_ajax
          click_button 'Create'

          expect(page).to have_current_path(spree.admin_order_return_authorizations_path(shipped_order))
          expect(page).to have_css('tr', text: price)
        end
      end
    end
  end

  def fill_in_pre_tax_amount(amount)
    input = find('input.refund-amount-input').click
    6.times { input.send_keys :right, :backspace }
    input.send_keys amount
  end
end

