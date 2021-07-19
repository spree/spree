require 'spec_helper'

describe 'Log entries', type: :feature do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:order) { create(:order, store: store) }
  let!(:payment) { create(:payment, order: order) }

  context 'with a successful log entry' do
    before do
      response = ActiveMerchant::Billing::Response.new(
        true,
        'Transaction successful',
        transid: 'ABCD1234'
      )

      payment.log_entries.create(
        source: payment.source,
        details: response.to_yaml
      )
    end

    it 'shows a successful attempt' do
      visit spree.admin_order_payments_path(order)
      find("#payment_#{payment.id} a", text: payment.number).click
      within find('#contentHeader') do
        click_link 'Logs'
      end

      within('#listing_log_entries') do
        expect(page).to have_content('Transaction successful')
      end
    end
  end

  context 'with a failed log entry' do
    before do
      response = ActiveMerchant::Billing::Response.new(
        false,
        'Transaction failed',
        transid: 'ABCD1234'
      )

      payment.log_entries.create(
        source: payment.source,
        details: response.to_yaml
      )
    end

    it 'shows a failed attempt' do
      visit spree.admin_order_payments_path(order)
      find("#payment_#{payment.id} a", text: payment.number).click
      within find('#contentHeader') do
        click_link 'Logs'
      end

      within('#listing_log_entries') do
        expect(page).to have_content('Transaction failed')
      end
    end
  end
end
