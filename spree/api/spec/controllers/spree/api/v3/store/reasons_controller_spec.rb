require 'spec_helper'

{
  Spree::Api::V3::Store::ReturnReasonsController => :return_reason,
  Spree::Api::V3::Store::ClaimReasonsController => :claim_reason
}.each do |controller_class, factory|
  RSpec.describe controller_class, type: :controller do
    render_views

    include_context 'API v3 Store'

    before do
      request.headers['X-Spree-Api-Key'] = api_key.token
      create(factory, store: store, name: 'Wrong size')
      create(factory, store: store, name: 'Damaged')
    end

    describe 'GET #index' do
      it_behaves_like 'a list without N+1 queries' do
        subject { get :index, as: :json }
      end

      it 'lists active reasons by name' do
        get :index, as: :json

        expect(json_response['data'].pluck('name')).to eq(['Damaged', 'Wrong size'])
      end
    end
  end
end
