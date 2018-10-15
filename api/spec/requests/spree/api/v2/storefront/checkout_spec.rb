require 'spec_helper'

describe 'API V2 Storefront Checkout Spec', type: :request do
  let!(:user)  { create(:user) }
  let!(:token) { Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: nil) }
  let!(:order) { create(:order_with_line_items, user: user) }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'checkout#next' do
    context 'without line items' do
      before do
        order.line_items.destroy_all
        patch '/api/v2/storefront/checkout/next', headers: headers
      end

      it 'cannot transition to address without a line item' do
        expect(response.status).to eq(422)
        expect(json_response['base']).to include(Spree.t(:there_are_no_items_for_this_order))
      end
    end

    context 'with line_items and email' do
      before do
        patch '/api/v2/storefront/checkout/next', headers: headers
      end

      it 'can transition an order to the next state' do
        expect(response.status).to       eq(200)
        expect(json_response['data']).to have_attribute(:state).with_value('address')
      end
    end

    context 'without payment info' do
      before do
        order.update_column(:state, 'payment')
        patch '/api/v2/storefront/checkout/next', headers: headers
      end

      it 'doesnt advance payment state if order has no payment' do
        expect(response.status).to       eq(422)
        expect(json_response['base']).to include(Spree.t(:no_payment_found))
      end
    end
  end

  describe 'checkout#advance' do
    context 'with payment data' do
      before do
        create(:payment, amount: order.total, order: order)
        patch '/api/v2/storefront/checkout/advance', headers: headers
      end

      it 'advances an order till complete or confirm step' do
        expect(response.status).to       eq(200)
        expect(json_response['data']).to have_attribute(:state).with_value('confirm')
      end
    end

    context 'without payment data' do
      before do
        patch '/api/v2/storefront/checkout/advance', headers: headers
      end

      it 'doesnt advance payment state if order has no payment' do
        expect(response.status).to       eq(422)
        expect(json_response['base']).to include(Spree.t(:no_payment_found))
      end
    end
  end

  describe 'checkout#complete' do
    context 'with payment data' do
      before do
        create(:payment, amount: order.total, order: order)
        patch '/api/v2/storefront/checkout/complete', headers: headers
      end

      it 'advances an order till complete step' do
        expect(response.status).to       eq(200)
        expect(json_response['data']).to have_attribute(:state).with_value('complete')
      end
    end

    context 'without payment data' do
      before do
        patch '/api/v2/storefront/checkout/complete', headers: headers
      end

      it 'returns errors' do
        expect(response.status).to       eq(422)
        expect(json_response['base']).to include(Spree.t(:no_payment_found))
      end
    end
  end

  describe 'checkout#update' do
    let!(:country_zone) { create(:zone, name: 'CountryZone') }
    let!(:state)        { create(:state) }
    let!(:country)      { state.country }
    # { country_zone.members.create(zoneable: country) }
    let!(:stock_location) { create(:stock_location) }

    let!(:shipping_method) { create(:shipping_method, zones: [country_zone]) }
    let!(:payment_method)  { create(:credit_card_payment_method) }

    before do
      allow_any_instance_of(Spree::Order).to receive_messages(confirmation_required?: true)
      allow_any_instance_of(Spree::Order).to receive_messages(payment_required?: true)
      put '/api/v2/storefront/checkout', params: params, headers: headers
    end

    context 'line_items' do
      let(:line_item) { order.line_items.first }
      let(:params) {
        {
          order: {
            line_items: {
              0 => {
                id: line_item.id,
                quantity: 2
              }
            }
          }
        }
      }

      it 'can update line_items' do
        expect(response.status).to eq(200)
      end
    end

    context 'addresses' do
      let(:country_zone) { create(:zone, name: 'CountryZone') }
      let(:state)        { create(:state) }
      let(:country)      { state.country }
      let!(:address) do
        {
          firstname:  'John',
          lastname:   'Doe',
          address1:   '7735 Old Georgetown Road',
          city:       'Bethesda',
          phone:      '3014445002',
          zipcode:    '20814',
          state_id:   state.id,
          country_id: country.id
        }
      end

      let(:params) {
        {
          order: {
            bill_address: address,
            ship_address: address
          }
        }
      }

      it 'can update addresses' do
        expect(response.status).to eq(200)

        expect(order.bill_address.first_name).to eq 'John'
        expect(order.ship_address.first_name).to eq 'John'
      end
    end

    context 'payment' do
      context 'payment method' do
        let(:params) {
          {
            order: {
              payments_attributes: [
                {
                  payment_method_id: payment_method.id
                }
              ]
            }
          }
        }

        it 'can update payment method' do
          expect(response.status).to eq(200)

          expect(order.payments.first.payment_method_id).to eq payment_method.id
        end
      end

      context 'payment source' do
        let(:source_attributes) {
          {
            number: '4111111111111111',
            month: 1.month.from_now.month,
            year: 1.month.from_now.year,
            verification_value: '123',
            name: 'Spree Commerce'
          }
        }
        let(:params) {
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
        }

        it 'can update payment method with source' do
          expect(response.status).to eq(200)

          expect(order.payments.last.source.name).to        eq('Spree Commerce')
          expect(order.payments.last.source.last_digits).to eq('1111')
        end
      end
    end

    context 'special instructions' do
      let(:params) {
        {
          order: {
            special_instructions: "Don't drop it"
          }
        }
      }

      it 'can update the special instructions for an order' do
        expect(response.status).to eq(200)
        expect(json_response['data']).to have_attribute(:special_instructions).with_value("Don't drop it")
      end
    end

    context 'email' do
      let(:params) {
        {
          order: {
            email: 'guest@spreecommerce.org'
          }
        }
      }

      it 'can assign an email to the order' do
        expect(response.status).to eq(200)
        expect(json_response['data']).to have_attribute(:email).with_value('guest@spreecommerce.org')
      end
    end

    context 'with invalid params' do
      let(:order) { create(:order_with_line_items, user: user, state: :delivery) }

      let(:params) {
        {
          order: {
            email: 'wrong_email'
          }
        }
      }

      it 'returns validation errors' do
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq('Customer E-Mail is invalid')
      end
    end
  end
end
