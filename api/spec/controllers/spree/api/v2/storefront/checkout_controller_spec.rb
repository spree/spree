require 'spec_helper'

describe 'Spree::Api::V2::Storefront::CheckoutController', type: :request do
  let(:user) { create(:user_with_addresses) }
  let(:params) { { order: order_attributes } }
  let(:store) { @default_store }

  include_context 'API v2 tokens'

  describe 'checkout#update' do
    subject :patch_update do
      patch '/api/v2/storefront/checkout', params: params, headers: headers_bearer
    end

    let(:order) { create(:order_with_line_items, user: user, state: 'address', store: store, bill_address_id: nil, ship_address_id: nil) }
    let(:headers_bearer) { { 'X-Spree-Order-Token' => order.token } }

    context 'with address attributes' do
      context 'with new address attributes' do
        let(:order_attributes) do
          {
            bill_address_attributes: {
              firstname: 'John',
              lastname: 'Doe',
              address1: '51 Guild Street',
              address2: '2nd floor',
              city: 'London',
              phone: '079 4721 9458',
              zipcode: 'SE25 3FZ',
              state_name: 'England',
              country_id: create(:country).id
            }
          }
        end

        it 'updates address from new attributes' do
          expect { patch_update }.to change { order.reload.bill_address&.firstname }.to('John')
        end
      end

      context 'with existing address attributes' do
        let(:order_attributes) do
          {
            bill_address_id: existing_address.id
          }
        end

        context 'with logged in user' do
          let(:existing_address) { create(:address, user: user) }

          it 'updates address from existing address' do
            expect { patch_update }.to change { order.reload.bill_address_id }.from(nil).to(existing_address.id)
          end
        end

        context 'with guest user' do
          let(:user) { nil }

          context 'with address that belongs to existing user' do
            let(:existing_address) { create(:address, user: create(:user)) }

            it 'does not update guest user address' do
              expect { patch_update }.not_to change { order.reload.bill_address_id }
            end
          end

          context 'with address that belongs to guest user' do
            let(:existing_address) { create(:address, user: nil) }

            it 'does not update guest user address' do
              expect { patch_update }.not_to change { order.reload.bill_address_id }
            end
          end
        end
      end
    end
  end
end
