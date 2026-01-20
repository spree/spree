require 'spec_helper'

RSpec.describe Spree::Admin::Orders::AdjustmentsController do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:order) { create(:order_with_line_items, store: store) }

  describe '#new' do
    subject { get :new, params: { order_id: order.number } }

    it 'returns a success response' do
      subject
      expect(response).to be_successful
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    let(:adjustment_params) { { label: 'Test Adjustment', amount: -10.00 } }

    context 'with turbo_stream format' do
      subject { post :create, params: { order_id: order.number, adjustment: adjustment_params }, format: :turbo_stream }

      it 'creates a new adjustment on order' do
        expect { subject }.to change { order.adjustments.reload.count }.by(1)
      end

      it 'responds with turbo_stream' do
        subject
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe '#edit' do
    subject { get :edit, params: { order_id: order.number, id: adjustment.id } }

    let(:adjustment) { create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5) }

    it 'returns a success response' do
      subject
      expect(response).to be_successful
      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    let(:adjustment) { create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5, state: 'open') }
    let(:update_params) { { label: 'Updated Label', amount: -15.00 } }

    context 'with turbo_stream format' do
      subject { put :update, params: { order_id: order.number, id: adjustment.id, adjustment: update_params }, format: :turbo_stream }

      it 'updates the adjustment' do
        subject
        adjustment.reload
        expect(adjustment.label).to eq('Updated Label')
      end

      it 'responds with turbo_stream' do
        subject
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe '#destroy' do
    let!(:adjustment) { create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5) }

    context 'with turbo_stream format' do
      subject { delete :destroy, params: { order_id: order.number, id: adjustment.id }, format: :turbo_stream }

      it 'destroys the adjustment' do
        expect { subject }.to change { Spree::Adjustment.count }.by(-1)
      end

      it 'responds with turbo_stream' do
        subject
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe '#toggle_state' do
    context 'when adjustment is open' do
      let(:adjustment) { create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5, state: 'open') }

      it 'closes the adjustment' do
        put :toggle_state, params: { order_id: order.number, id: adjustment.id }
        adjustment.reload
        expect(adjustment.state).to eq('closed')
      end
    end

    context 'when adjustment is closed' do
      let(:adjustment) { create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5, state: 'closed') }

      it 'opens the adjustment' do
        put :toggle_state, params: { order_id: order.number, id: adjustment.id }
        adjustment.reload
        expect(adjustment.state).to eq('open')
      end
    end

    it 'redirects to order edit page with HTML format' do
      adjustment = create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5)
      put :toggle_state, params: { order_id: order.number, id: adjustment.id }
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
    end

    it 'responds with turbo_stream format' do
      adjustment = create(:adjustment, adjustable: order, order: order, label: 'Manual', amount: -5)
      put :toggle_state, params: { order_id: order.number, id: adjustment.id }, format: :turbo_stream
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end
end
