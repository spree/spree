require 'spec_helper'

describe 'RefundReason', type: :feature, js: true do
  stub_authorization!

  let!(:amount) { 100.0 }
  let!(:payment_amount) { amount * 2 }
  let!(:payment_method) { create(:credit_card_payment_method) }
  let!(:payment) { create(:payment, amount: payment_amount, payment_method: payment_method) }
  let!(:refund_reason) { create(:default_refund_reason, mutable: true) }
  let!(:refund) { create(:refund, payment: payment, amount: amount, reason: refund_reason, transaction_id: nil) }
  let!(:refund_reason2) { create(:refund_reason, mutable: true) }

  before { visit spree.admin_refund_reasons_path }

  describe 'destroy' do
    it { expect(page).to have_content(refund_reason.name) }
    it { expect(page).to have_content(refund_reason2.name) }

    context 'should not destroy an associated option type' do
      before { within_row(2) { delete_product_property } }
      it { check_property_row_count(2) }
      it { expect(page).to have_content(refund_reason.name) }
      it { expect(page).to have_content(refund_reason2.name) }
    end

    context 'should allow an admin to destroy a non associated option type' do
      before { within_row(1) { delete_product_property } }
      it { expect(page).to have_content(refund_reason.name) }
      it { expect(page).not_to have_content(refund_reason2.name) }
      it { check_property_row_count(1) }
    end

    def delete_product_property
      page.evaluate_script('window.confirm = function() { return true; }')
      click_icon :delete
      wait_for_ajax
    end

    def check_property_row_count(expected_row_count)
      click_link 'Configuration'
      click_link 'Refund Reasons'
      expect(page).to have_css('tbody#refund_reasons')
      expect(all('tbody#refund_reasons tr').count).to eq(expected_row_count)
    end
  end
end
