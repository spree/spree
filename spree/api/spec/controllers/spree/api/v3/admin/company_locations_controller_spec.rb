require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompanyLocationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }
  let!(:location) { create(:company_location, company: company, name: 'Berlin') }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'returns the branch' do
      get :show, params: { id: location.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Berlin')
    end

    it '404s for a branch of another store company' do
      elsewhere = create(:company_location, company: create(:company, store: create(:store)))

      get :show, params: { id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    it 'renames the branch' do
      patch :update, params: { id: location.prefixed_id, name: 'Berlin Mitte' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(location.reload.name).to eq('Berlin Mitte')
    end

    context 'with an address already on file' do
      let!(:existing) { create(:business_address, address1: 'Alte Str 1', city: 'Berlin') }

      before { location.update!(billing_address: existing) }

      # Rebuilding would leave the old row behind and make one-field edits
      # impossible, since the replacement starts blank.
      it 'edits the address in place rather than replacing it' do
        expect {
          patch :update, params: {
            id: location.prefixed_id,
            billing_address: { address1: 'Neue Str 5' }
          }, as: :json
        }.not_to change(Spree::Address, :count)

        expect(response).to have_http_status(:ok)
        expect(location.reload.billing_address_id).to eq(existing.id)
        expect(existing.reload.address1).to eq('Neue Str 5')
        expect(existing.city).to eq('Berlin')
      end
    end

    it 'sets an address on a branch that had none' do
      germany = create(:country, iso: 'DE', name: 'Germany')

      patch :update, params: {
        id: location.prefixed_id,
        billing_address: {
          first_name: 'Anna', last_name: 'Muller', address1: 'Neue Str 5',
          city: 'Berlin', postal_code: '10115', country_code: germany.iso
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(location.reload.billing_address.address1).to eq('Neue Str 5')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the branch and the address it owned' do
      location.update!(billing_address: create(:business_address))

      expect { delete :destroy, params: { id: location.prefixed_id }, as: :json }.
        to change(Spree::Address, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
