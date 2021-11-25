require 'spec_helper'

describe 'Storefront API v2 CreditCards spec', type: :request do
  let!(:user) { create(:user) }
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
      expect(json_response['data'][0]).to have_attribute(:public_metadata)
    end
  end

  include_context 'API v2 tokens'

  describe 'credit_cards#index' do
    let(:payment_method_id) { credit_cards.first.payment_method_id }

    context 'with filter options' do
      before { get "/api/v2/storefront/account/credit_cards?filter[payment_method_id]=#{payment_method_id}&include=payment_method", headers: headers_bearer }

      it_behaves_like 'returns valid user credit cards resource JSON'

      it 'returns all user credit_cards' do
        expect(json_response['data'].count).to eq user.credit_cards.where(payment_method_id: payment_method_id).count
      end
    end

    context 'without options' do
      before { get '/api/v2/storefront/account/credit_cards', headers: headers_bearer }

      it_behaves_like 'returns valid user credit cards resource JSON'

      it 'returns all user credit_cards' do
        expect(json_response['data'][0]).to have_type('credit_card')
        expect(json_response['data'].size).to eq(credit_cards.count)
      end

      context 'user has credit cards that are not available on the front end' do
        let!(:credit_cards) { create_list(:credit_card, 3, user_id: user.id, payment_method: payment_method) }
        let(:payment_method) { create(:credit_card_payment_method, display_on: display_on, stores: stores) }
        let(:stores) { [Spree::Store.default] }
        let(:display_on) { :none }

        it 'does not return any' do
          expect(response.status).to eq(200)
          expect(json_response['data'].size).to eq(0)
        end

        context 'user has a credit cards available on the front end but in different store' do
          let(:stores) { [create(:store)] }
          let(:display_on) { :front_end }

          it 'does not return any' do
            expect(response.status).to eq(200)
            expect(json_response['data'].size).to eq(0)
          end
        end

        context 'deleted credit cards are omitted' do
          let!(:deleted_credit_card) { create(:credit_card, user_id: user.id, payment_method: payment_method, deleted_at: Time.current) }

          it 'returns all user credit_cards' do
            expect(json_response['data'].map(&:id)).not_to include(deleted_credit_card.id)
          end
        end
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/credit_cards' }

      it_behaves_like 'returns 403 HTTP status'
    end

    context 'when user has admin privileges' do
      let!(:user) { create(:admin_user) }
      let!(:new_user) { create(:user) }
      let!(:new_credit_card) { create(:credit_card, user_id: new_user.id, last_digits: '2222') }

      before { get '/api/v2/storefront/account/credit_cards', headers: headers_bearer }

      it 'should return user credit cards only' do
        expect(json_response['data'][0]).to have_type('credit_card')
        expect(json_response['data'].size).to eq(credit_cards.count)
        expect(json_response['data'].map { |card| card['attributes']['last_digits'] }).not_to include(new_credit_card.last_digits)
      end
    end
  end

  describe 'credit_cards#show' do
    let!(:default_credit_card) { create(:credit_card, user_id: user.id, default: true) }
    let!(:credit_card) { create(:credit_card, user_id: user.id, default: false) }

    context 'by "default"' do
      before { get '/api/v2/storefront/account/credit_cards/default', headers: headers_bearer }

      it 'returns user default credit_card' do
        expect(json_response['data']).to have_id(default_credit_card.id.to_s)
        expect(json_response['data']).to have_attribute(:cc_type).with_value(default_credit_card.cc_type)
        expect(json_response['data']).to have_attribute(:last_digits).with_value(default_credit_card.last_digits)
        expect(json_response['data']).to have_attribute(:name).with_value(default_credit_card.name)
        expect(json_response['data']).to have_attribute(:month).with_value(default_credit_card.month)
        expect(json_response['data']).to have_attribute(:year).with_value(default_credit_card.year)
      end
    end

    context 'by ID' do
      before { get "/api/v2/storefront/account/credit_cards/#{credit_card.id}", headers: headers_bearer }

      it 'returns proper credit_card' do
        expect(json_response['data']).to have_id(credit_card.id.to_s)
        expect(json_response['data']).to have_attribute(:cc_type).with_value(credit_card.cc_type)
        expect(json_response['data']).to have_attribute(:last_digits).with_value(credit_card.last_digits)
        expect(json_response['data']).to have_attribute(:name).with_value(credit_card.name)
        expect(json_response['data']).to have_attribute(:month).with_value(credit_card.month)
        expect(json_response['data']).to have_attribute(:year).with_value(credit_card.year)
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/credit_cards/default' }

      it_behaves_like 'returns 403 HTTP status'
    end

    context 'deleted credit card' do
      let!(:credit_card) { create(:credit_card, user_id: user.id, default: false) }

      before { credit_card.destroy }

      it 'returns 404 HTTP status' do
        get "/api/v2/storefront/account/credit_cards/#{credit_card.id}", headers: headers_bearer
        expect(response.status).to eq(404)
      end
    end
  end

  describe 'credit_cards#destroy' do
    context 'when credit card exist' do
      let!(:credit_card) { create(:credit_card, user_id: user.id) }

      it 'deletes a credit card' do
        delete "/api/v2/storefront/account/credit_cards/#{credit_card.id}", headers: headers_bearer

        expect(credit_card.reload.deleted_at).not_to be_nil
        expect(response.status).to eq(204)
      end

      context 'with missing authorization token' do
        before { delete "/api/v2/storefront/account/credit_cards/#{credit_card.id}" }

        it_behaves_like 'returns 403 HTTP status'
      end
    end

    context 'when credit card does not exist' do
      it 'should not find a credit card' do
        delete "/api/v2/storefront/account/credit_cards/dummy_id", headers: headers_bearer

        expect(response.status).to eq(404)
      end
    end
  end
end
