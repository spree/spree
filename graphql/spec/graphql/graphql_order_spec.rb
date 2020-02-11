require 'spec_helper'

context Spree::GraphqlController, type: :controller do
  context 'queries' do
    context 'fetch for non-admin' do
      let(:user) { create :user }
      let!(:order) { create :order, user: user }
      let(:access_token) { Spree::JwtToken.create_for_user(user)[:token] }
      let(:bearer) { "Bearer #{access_token}" }
      let(:query) { 'query { orders { id } }' }
      let(:exected) { [] }

      before { request.headers['X-Spree-JWT-Token'] = bearer }

      it do
        post :create, params: { query: query }
        expect(response.status).to eq(200)
        expect(json_response.dig(:data, :orders)).to eq(exected)
        expect(assigns(:spree_current_user)).to eq user
      end
    end

    context 'fetch all for admin' do
      let(:user) { create :admin_user }
      let!(:order) { create :completed_order_with_totals, user: user }
      let(:access_token) { Spree::JwtToken.create_for_user(user)[:token] }
      let(:bearer) { "Bearer #{access_token}" }
      let(:query) { 'query { orders { id } }' }
      let(:exected) { { 'id' => "#{order.id}" }}

      before { request.headers['X-Spree-JWT-Token'] = bearer }

      it do
        post :create, params: { query: query }
        expect(response.status).to eq(200)
        expect(json_response.dig(:data, :orders)).to eq([exected])
        expect(assigns(:spree_current_user)).to eq user
      end
    end

    context 'fetch with paginate', focus: true do
      let(:user) { create :admin_user }
      let!(:order) { create :completed_order_with_totals, user: user }
      let!(:order_2) { create :completed_order_with_totals, user: user }

      let(:access_token) { Spree::JwtToken.create_for_user(user)[:token] }
      let(:bearer) { "Bearer #{access_token}" }
      let(:query) { 'query { orders(page: 2, perPage: 1) { id } }' }
      let(:exected) { { 'id' => "#{order_2.id}" }}

      before { request.headers['X-Spree-JWT-Token'] = bearer }

      it do
        post :create, params: { query: query }
        expect(response.status).to eq(200)
        expect(json_response.dig(:data, :orders)).to eq([exected])
        expect(assigns(:spree_current_user)).to eq user
      end
    end

    context 'fetch current' do
      let!(:order) { create :order }

      let(:order_token) { Spree::JwtToken.create_for_order(order)[:order_token] }
      let(:query) { 'query { currentOrder { id, number } }' }
      let(:exected) { { 'id' => "#{order.id}", 'number' => order.number }}

      before { request.headers['X-Spree-JWT-Order-Token'] = order_token }

      it do
        post :create, params: { query: query }
        expect(response.status).to eq(200)
        expect(json_response.dig(:data, :currentOrder)).to eq(exected)
      end
    end
  end

  describe '#mutation' do
     describe '#cart' do
      let(:query) { 'mutation { cart { id, number } }' }
      let(:order) { ::Spree::Order.last }
      let(:exected) { { 'id' => "#{order.id}", 'number' => order.number }}

      it do
        post :create, params: { query: query }
        expect(response.status).to eq(200)
        expect(json_response.dig(:data, :cart)).to eq(exected)
      end
    end
  end
end
