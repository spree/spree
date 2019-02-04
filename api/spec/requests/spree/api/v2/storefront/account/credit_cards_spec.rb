require 'spec_helper'

describe 'Storefront API v2 CreditCards spec', type: :request do
  let!(:user) { create(:user) }
  let!(:params) { { user_id: user.id } }
  let!(:credit_cards) { create_list(:credit_card, 3, user_id: user.id) }

  shared_examples 'returns valid user credit cards resource JSON' do
    it 'returns a valid user credit cards resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data'][0]).to have_type('credit_card')
      expect(json_response['data'][0]).to have_relationships(:payment_method)
      expect(json_response['data'][0]).to have_attribute(:last_digits)
      expect(json_response['data'][0]).to have_attribute(:month)
      expect(json_response['data'][0]).to have_attribute(:year)
      expect(json_response['data'][0]).to have_attribute(:name)
    end
  end

  include_context 'API v2 tokens'

  describe 'credit_cards#index' do
    context 'with filter options' do
      before { get "/api/v2/storefront/account/credit_cards?filter[payment_method_id]=#{credit_cards.first.payment_method_id}&include=payment_method", headers: headers_bearer }

      it_behaves_like 'returns valid user credit cards resource JSON'

      it 'returns all user credit_cards' do
        expect(json_response['data'].size).to eq(1)
      end
    end

    context 'without options' do
      before { get '/api/v2/storefront/account/credit_cards', headers: headers_bearer }

      it_behaves_like 'returns valid user credit cards resource JSON'

      it 'returns all user credit_cards' do
        expect(json_response['data'][0]).to have_type('credit_card')
        expect(json_response['data'].size).to eq(credit_cards.count)
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/credit_cards' }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'credit_cards#show' do
    context 'by "default"' do
      let!(:default_credit_card) { create(:credit_card, user_id: user.id, default: true) }

      before { get '/api/v2/storefront/account/credit_cards/default', headers: headers_bearer }

      it 'returns user default credit_card' do
        expect(json_response['data']).to have_id(default_credit_card.id.to_s)
        expect(json_response['data']).to have_attribute(:cc_type).with_value(default_credit_card.cc_type)
        expect(json_response['data']).to have_attribute(:last_digits).with_value(default_credit_card.last_digits)
        expect(json_response['data']).to have_attribute(:name).with_value(default_credit_card.name)
        expect(json_response['data']).to have_attribute(:month).with_value(default_credit_card.month)
        expect(json_response['data']).to have_attribute(:year).with_value(default_credit_card.year)
        expect(json_response.size).to eq(1)
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/credit_cards/default' }

      it_behaves_like 'returns 403 HTTP status'
    end
  end
end
