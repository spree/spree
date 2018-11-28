require 'spec_helper'

require 'shared_examples/api_v2/base'
require 'shared_examples/api_v2/current_order'

describe 'API V2 Storefront Checkout Spec', type: :request do
  let(:default_currency) { 'USD' }
  let(:store) { create(:store, default_currency: default_currency) }
  let(:currency) { store.default_currency }
  let(:user)  { create(:user) }
  let(:order) { create(:order, user: user, store: store, currency: currency) }
  let(:payment) { create(:payment, amount: order.total, order: order) }
  let(:shipment) { create(:shipment, order: order) }

  include_context 'API v2 tokens'

  describe 'checkout#next' do
    let(:execute) { patch '/api/v2/storefront/checkout/next', headers: headers }

    shared_examples 'perform next' do
      context 'without line items' do
        before do
          order.line_items.destroy_all
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'cannot transition to address without a line item' do
          expect(json_response['error']).to include(Spree.t(:there_are_no_items_for_this_order))
        end
      end

      context 'with line_items and email' do
        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'can transition an order to the next state' do
          expect(order.reload.state).to eq('address')
          expect(json_response['data']).to have_attribute(:state).with_value('address')
        end
      end

      context 'without payment info' do
        before do
          order.update_column(:state, 'payment')
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response['error']).to include(Spree.t(:no_payment_found))
        end

        it 'doesnt advance pass payment state' do
          expect(order.reload.state).to eq('payment')
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform next'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform next'
    end
  end

  describe 'checkout#advance' do
    let(:execute) { patch '/api/v2/storefront/checkout/advance', headers: headers }

    shared_examples 'perform advance' do
      before do
        order.update_column(:state, 'payment')
      end

      context 'with payment data' do
        before do
          payment
          execute
        end

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'advances an order till complete or confirm step' do
          expect(order.reload.state).to eq('confirm')
          expect(json_response['data']).to have_attribute(:state).with_value('confirm')
        end
      end

      context 'without payment data' do
        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'doesnt advance pass payment state' do
          expect(order.reload.state).to eq('payment')
          expect(json_response['data']).to have_attribute(:state).with_value('payment')
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform advance'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform advance'
    end
  end

  describe 'checkout#complete' do
    let(:execute) { patch '/api/v2/storefront/checkout/complete', headers: headers }

    shared_examples 'perform complete' do
      before do
        order.update_column(:state, 'confirm')
      end

      context 'with payment data' do
        before do
          payment
          shipment
          execute
        end

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'completes an order' do
          expect(order.reload.state).to eq('complete')
          expect(order.completed_at).not_to be_nil
          expect(json_response['data']).to have_attribute(:state).with_value('complete')
        end
      end

      context 'without payment data' do
        before { execute }

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response['error']).to include(Spree.t(:no_payment_found))
        end

        it 'doesnt completes an order' do
          expect(order.reload.state).not_to eq('complete')
          expect(order.completed_at).to be_nil
        end
      end

      it_behaves_like 'no current order'
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform complete'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform complete'
    end
  end

  describe 'checkout#update' do
    let!(:country_zone) { create(:zone, name: 'CountryZone') }
    let!(:state)        { create(:state) }
    let!(:country)      { state.country }
    let!(:stock_location) { create(:stock_location) }

    let!(:shipping_method) { create(:shipping_method, zones: [country_zone]) }
    let!(:payment_method)  { create(:credit_card_payment_method) }

    let(:execute) { patch '/api/v2/storefront/checkout', params: params, headers: headers }

    include_context 'creates order with line item'

    before do
      allow_any_instance_of(Spree::PaymentMethod).to receive(:source_required?).and_return(false)
      allow_any_instance_of(Spree::Order).to receive_messages(confirmation_required?: true)
      allow_any_instance_of(Spree::Order).to receive_messages(payment_required?: true)
    end

    shared_examples 'perform update' do
      context 'addresses' do
        let(:address) do
          {
            firstname: 'John',
            lastname: 'Doe',
            address1: '7735 Old Georgetown Road',
            city: 'Bethesda',
            phone: '3014445002',
            zipcode: '20814',
            state_id: state.id,
            country_id: country.id
          }
        end

        let(:params) do
          {
            order: {
              bill_address_attributes: address,
              ship_address_attributes: address
            }
          }
        end

        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates addresses' do
          order.reload
          expect(order.bill_address).not_to be_nil
          expect(order.ship_address).not_to be_nil
          address.keys.each do |key|
            expect(order.bill_address[key]).to eq address[key]
          end
        end
      end

      context 'payment' do
        context 'payment method' do
          let(:params) do
            {
              order: {
                payments_attributes: [
                  {
                    payment_method_id: payment_method.id
                  }
                ]
              }
            }
          end

          before { execute }

          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'updates payment method' do
            expect(order.payments).not_to be_empty
            expect(order.payments.first.payment_method_id).to eq payment_method.id
          end
        end

        context 'payment source' do
          let(:source_attributes) do
            {
              number: '4111111111111111',
              month: 1.month.from_now.month,
              year: 1.month.from_now.year,
              verification_value: '123',
              name: 'Spree Commerce'
            }
          end
          let(:params) do
            {
              order: {
                payments_attributes: [
                  {
                    payment_method_id: payment_method.id
                  }
                ]
              },
              payment_source: {
                payment_method.id.to_s => source_attributes
              }
            }
          end

          before { execute }

          it_behaves_like 'returns 200 HTTP status'
          it_behaves_like 'returns valid cart JSON'

          it 'updates payment method with source' do
            expect(order.payments).not_to be_empty
            expect(order.payments.last.source.name).to eq('Spree Commerce')
            expect(order.payments.last.source.last_digits).to eq('1111')
          end
        end
      end

      context 'special instructions' do
        let(:params) do
          {
            order: {
              special_instructions: "Don't drop it"
            }
          }
        end

        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates the special instructions' do
          expect(order.reload.special_instructions).to eq("Don't drop it")
        end

        it 'returns updated special instructions' do
          expect(json_response['data']).to have_attribute(:special_instructions).with_value("Don't drop it")
        end
      end

      context 'email' do
        let(:params) do
          {
            order: {
              email: 'guest@spreecommerce.org'
            }
          }
        end

        before { execute }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns valid cart JSON'

        it 'updates email' do
          expect(order.reload.email).to eq('guest@spreecommerce.org')
        end

        it 'returns updated email' do
          expect(json_response['data']).to have_attribute(:email).with_value('guest@spreecommerce.org')
        end
      end

      context 'with invalid params' do
        let(:params) do
          {
            order: {
              email: 'wrong_email'
            }
          }
        end

        before do
          order.update_column(:state, 'delivery')
          execute
        end

        it_behaves_like 'returns 422 HTTP status'

        it 'returns an error' do
          expect(json_response['error']).to eq('Customer E-Mail is invalid')
        end

        it 'returns validation errors' do
          expect(json_response['errors']).to eq('email' => ['is invalid'])
        end
      end

      context 'without order' do
        let(:params) { {} }

        it_behaves_like 'no current order'
      end
    end

    context 'as a guest user' do
      include_context 'creates guest order with guest token'

      it_behaves_like 'perform update'
    end

    context 'as a signed in user' do
      include_context 'creates order with line item'

      it_behaves_like 'perform update'
    end
  end
end
