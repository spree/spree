require 'spec_helper'

context Spree::Graphql::GraphqlController, type: :controller do
  context 'queries' do
    context 'fetch for non-admin' do
      let!(:product) { create :product }
      let(:query) { 'query { products { id, name } }' }
      let(:exected) { { 'id' => "#{product.id}", 'name' => product.name }}


      it do
        api_post :create, query: query
        expect(response.status).to eq(200)
        expect(json_response.dig(:data, :products)).to eq([exected])
      end
    end
  end
end
