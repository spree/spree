require 'spec_helper'

RSpec.describe Spree::Admin::CustomerReturnsController do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }
  let!(:customer_return) { create(:customer_return, store: store) }

  describe '#index' do
    subject { get :index }

    it 'is successful' do
      subject
      expect(response).to be_successful
    end

    context 'when there are no customer returns' do
      before { Spree::CustomerReturn.destroy_all }

      it 'is successful' do
        subject
        expect(response).to be_successful
      end
    end
  end

  describe '#collection' do
    let!(:customer_returns) { create_list(:customer_return, 3, store: store) }

    it 'orders by created_at desc' do
      # Call the private method directly
      collection = controller.send(:collection)

      expect(collection).to eq [*customer_returns.reverse, customer_return]
    end

    it 'paginates the results' do
      allow(controller).to receive(:params).and_return({ per_page: '2', page: '1' })

      # Call the private method directly
      collection = controller.send(:collection)

      expect(collection.limit_value).to eq 2
      expect(collection.current_page).to eq 1
    end
  end
end
