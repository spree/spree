require 'spec_helper'
require 'spree/api/testing_support/helpers'

describe 'Cart Indicator Spec', type: :request do
  include Spree::Api::TestingSupport::Helpers

  let(:exec_get) { get '/cart_link' }

  shared_examples 'returns 0' do
    it 'with 200 HTTP status' do
      expect(response.status).to eq(200)
    end

    it 'with cart html' do
      expect(response.body).to include('<span class="font-weight-medium cart-icon-count">0</span>')
    end
  end

  shared_examples 'returns proper item count' do
    it 'with 200 HTTP status' do
      expect(response.status).to eq(200)
    end

    it 'returns 1' do
      expect(response.body).to include('<span class="font-weight-medium cart-icon-count">1</span>')
    end
  end

  context 'guest user' do
    context 'with already created order' do
      let(:order) { create(:order_with_line_items, user: nil, email: 'dummy@example.com') }

      before do
        allow_any_instance_of(Spree::StoreController).to receive_messages(simple_current_order: order)
        exec_get
      end

      it_behaves_like 'returns proper item count'
    end

    context 'without order' do
      before { exec_get }

      it_behaves_like 'returns 0'
    end
  end

  context 'signed in user' do
    let(:user) { create(:user) }

    context 'with already created order' do
      let(:order) { create(:order_with_line_items, user: user, email: 'dummy@example.com') }

      before do
        allow_any_instance_of(Spree::StoreController).to receive_messages(simple_current_order: order)
        exec_get
      end

      it_behaves_like 'returns proper item count'
    end

    context 'without order' do
      before { exec_get }

      it_behaves_like 'returns 0'
    end
  end
end
