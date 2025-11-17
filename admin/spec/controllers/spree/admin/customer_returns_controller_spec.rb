require 'spec_helper'

RSpec.describe Spree::Admin::CustomerReturnsController do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }
  let!(:customer_returns) { create_list(:customer_return, 3, store: store) }

  describe '#index' do
    subject { get :index }

    it 'is successful' do
      subject

      expect(response).to be_successful
      expect(assigns(:collection)).to contain_exactly(*customer_returns)
    end

    context 'when there are no customer returns' do
      let!(:customer_returns) { [] }

      it 'is successful' do
        subject
        expect(response).to be_successful
        expect(assigns(:collection)).to be_empty
      end
    end
  end
end
