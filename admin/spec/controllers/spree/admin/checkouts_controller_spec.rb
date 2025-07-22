require 'spec_helper'

describe Spree::Admin::CheckoutsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe '#index' do
    context 'with orders' do
      let!(:order) { create(:order_with_totals, store: store) }
      let!(:completed_order) { create(:completed_order_with_totals, store: store) }
      let(:line_item) { order.line_items.first }

      it 'renders index' do
        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'return all checkouts' do
        get :index
        expect(assigns(:orders).to_a).to include(order)
        expect(assigns(:orders).to_a).not_to include(completed_order)
      end

      context 'filtering by number' do
        let(:order) { create(:order, number: 'R123456789') }

        it 'returns orders with matching number' do
          get :index, params: { q: { number_cont: 'R123456789-10' } }
          expect(assigns(:orders).to_a).to include(order)
        end
      end
    end

    context 'without orders' do
      it 'renders index' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
