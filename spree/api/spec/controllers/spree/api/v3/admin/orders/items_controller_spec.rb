require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::ItemsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order, store: store, state: 'cart') }
  let!(:variant) { create(:variant, product: create(:product)) }

  describe 'GET #index' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    subject { get :index, params: { order_id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns line items' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { order_id: order.prefixed_id, variant_id: variant.prefixed_id, quantity: 2 }, as: :json }

    before { request.headers.merge!(headers) }

    it 'adds a line item' do
      expect { subject }.to change(order.line_items, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['quantity']).to eq(2)
    end

    # Authorization bypass: a read-only order role must not be able to mutate
    # an order it can only view — the key gate rejects the write with the same
    # 403 the read-only secret key gets below.
    context 'with a read-only order role' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permissions) { %w[read_orders] }

      it 'forbids adding a line item' do
        expect { subject }.not_to change(order.line_items, :count)

        expect(response).to have_http_status(:forbidden)
        expect(json_response.dig('error', 'details', 'required_permission')).to eq('write_orders')
      end
    end

    # The same property via the secret-API-key path: a read-only
    # `read_orders` key is rejected at the scope-check layer on a write.
    context 'with a read-only secret API key' do
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: [granted_scope]) }
      let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

      context 'granting only read_orders' do
        let(:granted_scope) { 'read_orders' }

        it 'forbids adding a line item with 403' do
          expect { subject }.not_to change(order.line_items, :count)

          expect(response).to have_http_status(:forbidden)
          expect(json_response['error']['details']['required_scope']).to eq('write_orders')
        end
      end

      context 'granting write_orders' do
        let(:granted_scope) { 'write_orders' }

        it 'adds a line item' do
          expect { subject }.to change(order.line_items, :count).by(1)

          expect(response).to have_http_status(:created)
        end
      end
    end
  end

  describe 'POST #create with a negotiated price' do
    subject do
      post :create, params: { order_id: order.prefixed_id, variant_id: variant.prefixed_id, quantity: 10, price: '7.20' }, as: :json
    end

    before { request.headers.merge!(headers) }

    it 'adds the line at the negotiated price, stamped manual' do
      subject

      expect(response).to have_http_status(:created)
      line_item = order.line_items.sole
      expect(line_item.price).to eq(7.2)
      expect(line_item.price_source).to eq('manual')
      expect(json_response['price_source']).to eq('manual')
    end

    context 'with an unusable price' do
      subject do
        post :create, params: { order_id: order.prefixed_id, variant_id: variant.prefixed_id, quantity: 1, price: 'NaN' }, as: :json
      end

      it 'refuses with the invalid_price code' do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('invalid_price')
      end
    end

    context 'with a price on a placed order' do
      before { order.update_columns(status: 'placed', completed_at: Time.current) }

      subject do
        post :create, params: { order_id: order.prefixed_id, variant_id: variant.prefixed_id, quantity: 1, price: '7.20' }, as: :json
      end

      it 'refuses with the price_override_not_allowed code' do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('price_override_not_allowed')
      end

      context 'with a non-numeric price' do
        subject do
          post :create, params: { order_id: order.prefixed_id, variant_id: variant.prefixed_id, quantity: 1, price: 'NaN' }, as: :json
        end

        it 'still refuses with price_override_not_allowed' do
          subject

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['error']['code']).to eq('price_override_not_allowed')
        end
      end
    end
  end

  describe 'PATCH #update' do
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

    subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, quantity: 5 }, as: :json }

    before { request.headers.merge!(headers) }

    it 'updates the line item quantity' do
      subject

      expect(response).to have_http_status(:ok)
      expect(line_item.reload.quantity).to eq(5)
    end

    context 'with a negotiated price' do
      subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, price: '7.20' }, as: :json }

      it 'stamps the line manual at the given price' do
        subject

        expect(response).to have_http_status(:ok)
        expect(line_item.reload.price).to eq(7.2)
        expect(line_item.price_source).to eq('manual')
        expect(json_response['price_source']).to eq('manual')
      end

      it 'leaves pricing alone when the request carries no price key' do
        patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, quantity: 2 }, as: :json

        expect(line_item.reload.price_source).to be_nil
      end
    end

    context 'reverting a negotiated price with an explicit null' do
      before do
        line_item.update_columns(price: 7.2, price_source: Spree::LineItem::MANUAL_PRICE_SOURCE)
      end

      subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, price: nil }, as: :json }

      it 'clears the marker and re-prices from the catalog' do
        catalog_price = variant.price_in(order.currency).amount

        subject

        expect(response).to have_http_status(:ok)
        expect(line_item.reload.price).to eq(catalog_price)
        expect(line_item.price_source).to be_nil
      end
    end

    context 'with a price on a placed order' do
      before { order.update_columns(status: 'placed', completed_at: Time.current) }

      subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, price: '7.20' }, as: :json }

      it 'refuses with 422 and an actionable message' do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('price_override_not_allowed')
        expect(response.body).to include('placed order')
        expect(line_item.reload.price_source).to be_nil
      end

      context 'with a non-numeric price' do
        subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, price: 'NaN' }, as: :json }

        it 'still refuses with price_override_not_allowed' do
          subject

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['error']['code']).to eq('price_override_not_allowed')
        end
      end
    end

    context 'with an unusable price' do
      subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, price: 'NaN' }, as: :json }

      it 'refuses with 422 and an actionable message' do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('invalid_price')
        expect(response.body).to include('non-negative number')
        expect(line_item.reload.price_source).to be_nil
      end
    end

    context 'with a negative price' do
      subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, price: '-1' }, as: :json }

      it 'refuses with the invalid_price code' do
        subject

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('invalid_price')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:line_item) { create(:line_item, order: order, variant: variant) }

    subject { delete :destroy, params: { order_id: order.prefixed_id, id: line_item.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'removes the line item' do
      subject
      expect(response).to have_http_status(:no_content)
    end
  end
end
