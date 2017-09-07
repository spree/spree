require 'spec_helper'

module Spree
  describe Api::V1::ReimbursementsController, type: :controller do
    render_views

    before do
      stub_authentication!
    end

    describe '#index' do
      let!(:reimbursement) { create(:reimbursement) }

      before do
        api_get :index
      end

      it 'loads reimbursements' do
        expect(response.status).to eq(200)
        expect(json_response['count']).to eq(1)
      end
    end
  end
end
