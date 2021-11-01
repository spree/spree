require 'spec_helper'

describe 'Platform API v2 Payment Methods', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let!(:store) { Spree::Store.default }

  let!(:resource_a) { create(:payment_method, stores: [store]) }
  let!(:resource_b) { create(:payment_method, stores: [store]) }
  let!(:resource_c) { create(:payment_method, stores: [store]) }
  let!(:resource_d) { create(:payment_method, stores: [store]) }
  let!(:resource_e) { create(:payment_method, stores: [store]) }

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'payment_methods#update' do
    context 'move resource_a from position 1 down to position 5' do
      let(:params) do
        {
          payment_method: { position: 5 }
        }
      end

      before do
        patch "/api/v2/platform/payment_methods/#{resource_a.id}", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves resource_a from position 1 to position 5 and updates the positions of its siblings accordingly' do
        reload_sections

        expect(resource_b.position).to eq(1)
        expect(resource_c.position).to eq(2)
        expect(resource_d.position).to eq(3)
        expect(resource_e.position).to eq(4)
        expect(resource_a.position).to eq(5)
      end
    end

    context 'can move position and update other attribute' do
      let(:params) do
        {
          payment_method: {
            name: 'Rename resource and update Position!',
            position: 1
          }
        }
      end

      before do
        patch "/api/v2/platform/payment_methods/#{resource_d.id}", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves resource_d from position 4 to position 1, and updates the name' do
        reload_sections
        expect(resource_d.position).to eq(1)
        expect(resource_d.name).to eq('Rename resource and update Position!')
      end
    end

    def reload_sections
      resource_a.reload
      resource_b.reload
      resource_c.reload
      resource_d.reload
      resource_e.reload
    end
  end
end
