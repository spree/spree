require 'spec_helper'

module Spree
  describe Api::V1::CustomerReturnsController, type: :controller do
    render_views

    before do
      stub_authentication!
      @customer_return = create(:customer_return)
    end

    describe '#index' do
      let(:order)           { customer_return.order }
      let(:customer_return) { create(:customer_return) }

      before do
        api_get :index
      end

      it 'loads customer returns' do
        expect(response.status).to eq(200)
        expect(json_response['count']).to eq(1)
      end
    end
  end
end
