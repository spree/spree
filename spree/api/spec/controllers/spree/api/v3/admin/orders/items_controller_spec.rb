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
    # an order it can only view. `authorize_order_access!` requires :update for
    # writes, so OrderDisplay (read-only) is rejected.
    context 'with a read-only order role' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permission_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can [:read, :admin], Spree::Order
            can [:read, :admin], Spree::LineItem
          end
        end
      end

      it 'forbids adding a line item' do
        expect { subject }.not_to change(order.line_items, :count)

        expect(response).to have_http_status(:forbidden)
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

  describe 'PATCH #update' do
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 1) }

    subject { patch :update, params: { order_id: order.prefixed_id, id: line_item.prefixed_id, quantity: 5 }, as: :json }

    before { request.headers.merge!(headers) }

    it 'updates the line item quantity' do
      subject

      expect(response).to have_http_status(:ok)
      expect(line_item.reload.quantity).to eq(5)
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
