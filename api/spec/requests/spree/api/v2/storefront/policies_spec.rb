require 'spec_helper'

describe 'Storefront API v2 Policies spec', type: :request do
  let(:store) { Spree::Store.default }
  let(:other_store) { create(:store, name: 'Other Store') }
  let!(:policy) { store.policies.first }

  before do
    allow_any_instance_of(Spree::Api::V2::Storefront::PoliciesController).to receive(:current_store).and_return(store)
  end

  describe 'policies#index' do
    let!(:other_store_policy) { create(:policy, slug: 'other-store-policy', store: other_store) }

    before { get '/api/v2/storefront/policies' }

    it 'returns policies for current store' do
      expect(json_response['data'].count).to eq(4)
      policy_names = json_response['data'].map { |p| p['attributes']['name'] }
      expect(policy_names).to include('Privacy Policy', 'Terms of Service', 'Returns Policy', 'Shipping Policy')
      expect(policy_names).not_to include('My Policy') # other store policy
    end
  end

  describe 'policies#show' do
    context 'with slug param' do
      before { get "/api/v2/storefront/policies/#{policy.slug}" }

      it 'returns policy with attributes' do
        expect(json_response['data']['id']).to eq(policy.id.to_s)
        expect(json_response['data']['type']).to eq('policy')
        expect(json_response['data']['attributes']['name']).to eq(policy.name)
        expect(json_response['data']['attributes']['slug']).to eq(policy.slug)
        expect(json_response['data']['attributes']['body']).to eq(policy.body.to_plain_text)
        expect(json_response['data']['attributes']['body_html']).to eq(policy.body.to_s)
        expect(json_response['data']['attributes']['created_at']).to be_present
        expect(json_response['data']['attributes']['updated_at']).to be_present
      end
    end

    context 'with id param' do
      before { get "/api/v2/storefront/policies/#{policy.id}" }

      it 'returns policy with attributes' do
        expect(response.status).to eq(200)
        expect(json_response['data']['id']).to eq(policy.id.to_s)
      end
    end

    context 'with locale set to pl' do
      let!(:localized_policy) do
        policy = create(:policy, store: store, slug: 'localized-policy', name: 'Privacy Policy EN')

        I18n.with_locale(:pl) do
          policy.name = 'Polityka Prywatności'
          policy.body = 'To jest polityka prywatności'
          policy.save!
        end

        policy
      end

      before do
        store.update!(supported_locales: 'en,pl')
        get "/api/v2/storefront/policies/#{localized_policy.slug}?locale=pl"
      end

      after do
        I18n.locale = :en
        store.update!(supported_locales: 'en')
      end

      it 'returns policy with translated attributes' do
        expect(json_response['data']).to have_attribute(:name).with_value('Polityka Prywatności')
        expect(json_response['data']).to have_attribute(:body).with_value('To jest polityka prywatności')
      end
    end

    context 'with invalid slug param' do
      before { get '/api/v2/storefront/policies/non-existent-policy' }

      it 'returns error' do
        expect(json_response['error']).to eq('The resource you were looking for could not be found.')
      end
    end

    context 'with invalid id param' do
      before { get '/api/v2/storefront/policies/999999' }

      it 'returns error' do
        expect(json_response['error']).to eq('The resource you were looking for could not be found.')
      end
    end

    context 'accessing policy from different store' do
      let(:other_store_policy) { create(:policy, store: other_store, slug: 'other-policy') }

      before { get "/api/v2/storefront/policies/#{other_store_policy.slug}" }

      it 'returns error when policy belongs to different store' do
        expect(json_response['error']).to eq('The resource you were looking for could not be found.')
      end
    end
  end
end
