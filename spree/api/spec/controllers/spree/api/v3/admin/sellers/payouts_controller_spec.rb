require 'spec_helper'

# Settling a seller by hand — what the `manual` interval means, and the
# escape hatch for paying anyone early.
RSpec.describe Spree::Api::V3::Admin::Sellers::PayoutsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store) }

  def earn(amount, currency: 'USD')
    create(:seller_transfer, :completed, seller: seller, amount: amount, currency: currency,
                                         order: create(:completed_order_with_totals, store: store, seller: seller))
  end

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    it 'settles what the seller is owed' do
      earn(40)
      earn(30)

      post :create, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      row = json_response['data'].first
      expect(row['display_amount']).to eq('$70.00')
      expect(seller.seller_transfers.unsettled).to be_empty
    end

    # Nothing is ever converted between currencies, so a seller trading in two
    # is settled in each.
    it 'settles each currency separately' do
      earn(40)
      earn(30, currency: 'EUR')

      post :create, params: { seller_id: seller.prefixed_id }, as: :json

      amounts = json_response['data'].map { |row| row['currency'] }
      expect(amounts).to contain_exactly('USD', 'EUR')
    end

    # The sweep halts rather than failing when there is nothing to send, which
    # from here reads as success with no payout — worth saying plainly.
    it 'says so when there is nothing to settle' do
      post :create, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to eq('This seller has nothing to settle right now.')
    end

    it 'leaves an earning below the seller minimum alone' do
      seller.update!(minimum_payout_amount: 100)
      earn(40)

      post :create, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.seller_transfers.unsettled.count).to eq(1)
    end

    # A provider refusing is not the same as having nothing to send: the
    # payout row exists and is failed or unresolved, and an operator told
    # "nothing to settle" would never go looking for it.
    context 'when the payout provider refuses' do
      before do
        earn(40)
        refusal = Spree::ServiceModule::Result.new(
          false, nil, Spree::ServiceModule::ResultError.new('Gateway declined')
        )
        allow(Spree.seller_payout_sweep_workflow).to receive(:call).and_return(refusal)
      end

      it 'reports the refusal rather than reporting nothing to settle' do
        post :create, params: { seller_id: seller.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['message']).to include('Gateway declined')
      end
    end

    it "404s on another marketplace's seller" do
      other = create(:seller, :approved, store: create(:store))

      post :create, params: { seller_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    context 'with a role that may read payouts but not write them' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permissions) { %w[read_payouts] }

      it 'is refused' do
        post :create, params: { seller_id: seller.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
