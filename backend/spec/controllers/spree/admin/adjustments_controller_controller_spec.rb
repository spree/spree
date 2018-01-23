require 'spec_helper'

module Spree
  module Admin
    describe AdjustmentsController, type: :controller do
      stub_authorization!

      describe '#index' do
        let!(:order) { create(:order) }
        let!(:adjustment_1) { create(:adjustment, order: order) }
        let!(:adjustment_2) { create(:adjustment, order: order, eligible: false) }

        subject do
          spree_get :index, order_id: order.to_param
        end

        before { subject }

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
    end
  end
end
