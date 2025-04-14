require 'spec_helper'

RSpec.describe 'Checkout page', type: :feature do
  describe '#payment_methods' do
    let(:order) { create(:order_with_line_items) }
    let(:payment_method) { create(:payment_method, type: type) }

    before do
      Rails.application.config.spree.payment_methods << type

      stub_authentication!(order.user)
    end

    context 'when payment method is of type `test`' do
      let(:type) { Spree::Gateway::Test }

      it 'displays the example payment method' do
        visit spree.checkout_state_path(order.token, state: 'payment', payment_method_id: payment_method.id)

        expect(page).to have_selector('div.test-payment', text: 'This is a test payment method!')
      end
    end
  end
end
