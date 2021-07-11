require 'spec_helper'
require 'cancan'
require 'spree/testing_support/bar_ability'

describe Spree::Admin::Orders::CustomerDetailsController, type: :controller do
  context 'with authorization' do
    stub_authorization!

    let(:store) { Spree::Store.default }
    let(:user) { create(:user) }
    let(:country) { create(:country) }
    let(:state) { create(:state, country: country) }

    let(:order) do
      create(:order_with_line_items, total: 100, number: 'R123456789', store: store, state: 'cart', user: nil, email: 'john@snow.org')
    end

    let(:valid_attributes) do
      {
        order_id: order.number,
        order: {
          email: '',
          use_billing: '',
          bill_address_attributes: build(:address, firstname: 'Jane', country: country, state: state).attributes,
          ship_address_attributes: build(:address, firstname: 'Jane', country: country, state: state).attributes,
          user_id: user.id.to_s
        },
        guest_checkout: guest_checkout
      }
    end

    describe '#update' do
      let(:attributes) { valid_attributes }

      def send_request(params = {})
        put :update, params: params
      end

      before { send_request(attributes) }

      context 'using guest checkout' do
        let(:guest_checkout) { 'true' }

        context 'valid parameters' do
          it { expect(response).to redirect_to(edit_admin_order_url(order)) }
          it { expect(order.reload.bill_address.firstname).to eq('Jane') }
          it { expect(order.reload.user).to be_nil }
        end

        context 'invalid parameters' do
          let(:attributes) do
            valid_attributes.deep_merge(order: { ship_address_attributes: { 'firstname' => '' } })
          end

          it { expect(response).to render_template(:edit) }
        end
      end

      context 'user order' do
        let(:guest_checkout) { 'false' }

        context 'valid parameters' do
          it { expect(response).to redirect_to(edit_admin_order_url(order)) }
          it { expect(order.reload.bill_address.firstname).to eq('Jane') }
          it { expect(order.reload.user).to eq(user) }
        end

        context 'invalid parameters' do
          let(:attributes) do
            valid_attributes.merge(guest_checkout: 'false', order: { user_id: 99_999_999 })
          end

          it { expect(response).to render_template(:edit) }
        end
      end
    end
  end
end
