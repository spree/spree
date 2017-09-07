require 'spec_helper'

describe 'Log entries', type: :feature do
  stub_authorization!

  let!(:payment) { create(:payment) }

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
      visit spree.admin_order_payments_path(payment.order)
      find("#payment_#{payment.id} a").click
      click_link 'Logs'
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
      visit spree.admin_order_payments_path(payment.order)
      find("#payment_#{payment.id} a").click
      click_link 'Logs'
      within('#listing_log_entries') do
        expect(page).to have_content('Transaction failed')
      end
    end
  end
end
