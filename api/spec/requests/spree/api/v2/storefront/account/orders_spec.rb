require 'spec_helper'

describe 'Storefront API v2 Orders spec', type: :request do
  let(:store) { @default_store }
  let!(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order, state: 'complete', user: user, completed_at: Time.current, store: store) }

  before do
    allow(Spree::Api::Config).to receive(:[]).and_call_original
    allow(Spree::Api::Config).to receive(:[]).with(:api_v2_per_page_limit).and_return(2)
  end

  include_context 'API v2 tokens'

  def expect_order_json(json)
    expect(json).to be_present
    expect(json).to have_id(order.id.to_s)
    expect(json).to have_type('order')
    expect(json).to have_attribute(:number).with_value(order.number)
    expect(json).to have_attribute(:state).with_value(order.state)
    expect(json).to have_attribute(:token).with_value(order.token)
    expect(json).to have_attribute(:total).with_value(order.total.to_s)
    expect(json).to have_attribute(:item_total).with_value(order.item_total.to_s)
    expect(json).to have_attribute(:ship_total).with_value(order.ship_total.to_s)
    expect(json).to have_attribute(:adjustment_total).with_value(order.adjustment_total.to_s)
    expect(json).to have_attribute(:included_tax_total).with_value(order.included_tax_total.to_s)
    expect(json).to have_attribute(:additional_tax_total).with_value(order.additional_tax_total.to_s)
    expect(json).to have_attribute(:display_additional_tax_total).with_value(order.display_additional_tax_total.to_s)
    expect(json).to have_attribute(:display_included_tax_total).with_value(order.display_included_tax_total.to_s)
    expect(json).to have_attribute(:tax_total).with_value(order.tax_total.to_s)
    expect(json).to have_attribute(:currency).with_value(order.currency.to_s)
    expect(json).to have_attribute(:email).with_value(order.email)
    expect(json).to have_attribute(:display_item_total).with_value(order.display_item_total.to_s)
    expect(json).to have_attribute(:display_ship_total).with_value(order.display_ship_total.to_s)
    expect(json).to have_attribute(:display_adjustment_total).with_value(order.display_adjustment_total.to_s)
    expect(json).to have_attribute(:display_tax_total).with_value(order.display_tax_total.to_s)
    expect(json).to have_attribute(:item_count).with_value(order.item_count)
    expect(json).to have_attribute(:special_instructions).with_value(order.special_instructions)
    expect(json).to have_attribute(:promo_total).with_value(order.promo_total.to_s)
    expect(json).to have_attribute(:display_promo_total).with_value(order.display_promo_total.to_s)
    expect(json).to have_attribute(:display_total).with_value(order.display_total.to_s)
    expect(json).to have_attribute(:public_metadata).with_value(order.public_metadata)
    expect(json).to have_relationships(:user, :line_items, :variants, :billing_address, :shipping_address, :payments, :shipments, :promotions)
  end

  describe 'orders#index' do
    context 'with option: include' do
      before { get '/api/v2/storefront/account/orders?include=billing_address', headers: headers_bearer }

      it 'returns orders' do
        expect(json_response['data'].size).to eq 1
        expect(json_response['data']).to be_kind_of(Array)

        expect_order_json(json_response['data'].first)
      end

      it 'returns included resource' do
        expect(json_response['included'].size).to eq Spree::Order.count
        expect(json_response['included'][0]).to have_type('address')
      end
    end

    context 'when per_page is between 1 and default value' do
      let!(:order) { create(:order, state: 'complete', user: user, completed_at: Time.current, store: store) }
      let!(:order_1) { create(:order, state: 'complete', user: user, completed_at: Time.current + 1.day, store: store) }
      let!(:order_2) { create(:order, state: 'complete', user: user, completed_at: Time.current + 2.days, store: store) }
      let!(:order_3) { create(:order, state: 'complete', user: user, completed_at: Time.current + 3.days, store: store) }

      context 'with specified pagination params' do
        before { get '/api/v2/storefront/account/orders?page=1&per_page=2', headers: headers_bearer }

        it 'returns specified amount orders' do
          expect(json_response['data'].count).to eq 2
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq 2
          expect(json_response['meta']['total_count']).to eq Spree::Order.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/account/orders?page=1&per_page=2')
          expect(json_response['links']['next']).to include('/api/v2/storefront/account/orders?page=2&per_page=2')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/account/orders?page=1&per_page=2')
        end
      end

      context 'when per_page is above the default value' do
        before { get '/api/v2/storefront/account/orders?page=1&per_page=10', headers: headers_bearer }

        it 'returns the default number of orders' do
          expect(json_response['data'].count).to eq 4
        end
      end

      context 'when per_page is less than 0' do
        before { get '/api/v2/storefront/account/orders?page=1&per_page=-1', headers: headers_bearer }

        it 'returns the default number of orders' do
          expect(json_response['data'].count).to eq 4
        end
      end

      context 'when per_page is equal 0' do
        before { get '/api/v2/storefront/account/orders?page=1&per_page=0', headers: headers_bearer }

        it 'returns the default number of orders' do
          expect(json_response['data'].count).to eq 4
        end
      end
    end

    context 'without specified pagination params' do
      before { get '/api/v2/storefront/account/orders', headers: headers_bearer }

      it 'returns specified amount orders' do
        expect(json_response['data'].count).to eq Spree::Order.count
      end

      it 'returns proper meta data' do
        expect(json_response['meta']['count']).to       eq Spree::Order.count
        expect(json_response['meta']['total_count']).to eq Spree::Order.count
      end

      it 'returns proper links data' do
        expect(json_response['links']['self']).to include('/api/v2/storefront/account/orders')
        expect(json_response['links']['next']).to include('/api/v2/storefront/account/orders?page=1')
        expect(json_response['links']['prev']).to include('/api/v2/storefront/account/orders?page=1')
      end
    end

    context 'sort orders' do
      let!(:order) { create(:order, state: 'complete', user: user, completed_at: Time.current) }
      let!(:order_1) { create(:order, state: 'complete', user: user, completed_at: Time.current + 1.day) }
      let!(:order_2) { create(:order, state: 'complete', user: user, completed_at: Time.current + 2.days) }
      let!(:order_3) { create(:order, state: 'complete', user: user, completed_at: Time.current + 3.days) }

      context 'sorting by completed_at' do
        context 'ascending order' do
          before { get '/api/v2/storefront/account/orders?sort=completed_at', headers: headers_bearer }

          it 'returns orders sorted by completed_at' do
            expect(json_response['data'].count).to eq store.orders.count
            expect(json_response['data'].pluck(:id)).to eq store.orders.select('*').order(completed_at: :asc).pluck(:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/account/orders?sort=-completed_at', headers: headers_bearer }

          it 'returns orders sorted by completed_at' do
            expect(json_response['data'].count).to eq store.orders.count
            expect(json_response['data'].pluck(:id)).to eq store.orders.select('*').order(completed_at: :desc).pluck(:id).map(&:to_s)
          end
        end
      end
    end

    context 'do not return orders from different stores' do
      let!(:order_2) { create(:order, state: 'complete', user: user, completed_at: Time.current, store: create(:store)) }

      before { get '/api/v2/storefront/account/orders', headers: headers_bearer }

      it 'returns orders sorted by completed_at' do
        expect(json_response['data'].count).to eq 1
        expect(json_response['data'].pluck(:id)).not_to include(order_2.id.to_s)
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/orders' }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'orders#show' do
    let(:user) { create(:user_with_addresses) }
    let(:order) { create(:order, state: 'complete', user: user, completed_at: Time.current, store: store) }

    context 'without option: include' do
      before { get "/api/v2/storefront/account/orders/#{order.number}", headers: headers_bearer }

      it 'returns valid order JSON' do
        expect_order_json(json_response['data'])
      end
    end

    context 'with option: include' do
      before { get "/api/v2/storefront/account/orders/#{order.number}?include=billing_address", headers: headers_bearer }

      it 'returns valid order JSON' do
        expect_order_json(json_response['data'])
      end

      it 'return hash with included' do
        expect(json_response['included']).to be_present
        expect(json_response['included'][0]).to have_type('address')
      end
    end

    context 'with missing order number' do
      before { get '/api/v2/storefront/account/orders/23212', headers: headers_bearer }

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/orders' }

      it_behaves_like 'returns 403 HTTP status'
    end

    context 'do not return order from different stores' do
      let!(:order_2) { create(:order, state: 'complete', user: user, completed_at: Time.current, store: create(:store)) }

      before { get "/api/v2/storefront/account/orders/#{order_2.number}", headers: headers_bearer }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
