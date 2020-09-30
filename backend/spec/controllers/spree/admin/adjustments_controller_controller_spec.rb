require 'spec_helper'

module Spree
  module Admin
    describe AdjustmentsController, type: :controller do
      stub_authorization!

      describe '#index' do
        subject do
          get :index, params: { order_id: order.to_param }
        end

        let!(:order) { create(:order) }
        let!(:adjustment_1) { create(:adjustment, order: order) }

        before do
          create(:adjustment, order: order, eligible: false) # adjustment_2
          subject
        end

        it 'returns 200 status' do
          expect(response.status).to eq 200
        end

        it 'loads the order' do
          expect(assigns(:order)).to eq order
        end

        it 'returns only eligible adjustments' do
          expect(assigns(:adjustments)).to match_array([adjustment_1])
        end
      end

      describe '#destroy' do
        subject do
          delete :destroy, params: { order_id: order.to_param, id: adjustment.id }
        end

        let!(:order) { create(:order) }
        let!(:adjustment) { create(:adjustment, order: order) }

        context 'when adjustment is destroyed' do
        end

        context 'when adjustment is not destroyed' do

        end
      end
    end
  end
end
