require 'spec_helper'

# Covers AdminAuthentication using TaxCategoriesController as a representative
# Admin::ResourceController — the mechanic applies to every admin endpoint.
RSpec.describe Spree::Api::V3::Admin::TaxCategoriesController, type: :controller do
  render_views

  include_context 'API v3 Admin'

  let!(:tax_category) { create(:tax_category, name: 'Standard') }

  describe 'secret API key authentication' do
    context 'with a valid key' do
      before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

      it 'authenticates and resolves to the ApiKeyAbility' do
        get :index, as: :json

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_api_key)).to eq(secret_api_key)
        expect(controller.send(:current_ability)).to be_a(Spree::ApiKeyAbility)
      end
    end

    context 'with no key and no JWT' do
      it 'returns 401' do
        get :index, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with an unknown key' do
      before { request.headers['X-Spree-Api-Key'] = 'sk_does_not_exist' }

      it 'returns 401' do
        get :index, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the key belongs to a different store' do
      let(:other_store) { create(:store, default: false, code: 'other') }
      let(:foreign_key) { create(:api_key, :secret, store: other_store) }

      before { request.headers['X-Spree-Api-Key'] = foreign_key.plaintext_token }

      it 'returns 401 (cross-store keys are rejected)' do
        get :index, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # Regression: +set_resource+ ran before +authenticate_admin!+, so
  # +current_ability+ was the unauthenticated +Spree::Ability+ and
  # +scope.accessible_by+ returned no rows → 404 on show/update/destroy.
  describe 'auth ordering — +authenticate_request!+ runs before +set_resource+' do
    before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

    it 'GET show returns 200 (not 404)' do
      get :show, params: { id: tax_category.prefixed_id }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'PATCH update returns 200 (not 404)' do
      patch :update, params: { id: tax_category.prefixed_id, name: 'Reduced' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(tax_category.reload.name).to eq('Reduced')
    end

    it 'DELETE destroy returns 204 (not 404)' do
      delete :destroy, params: { id: tax_category.prefixed_id }, as: :json
      expect(response).to have_http_status(:no_content)
    end

    it 'declares +authenticate_request!+ before +set_resource+ in the callback chain' do
      callbacks = described_class._process_action_callbacks
                                 .select { |c| c.kind == :before }
                                 .map(&:filter)
      auth_index = callbacks.index(:authenticate_request!)
      set_resource_index = callbacks.index(:set_resource)

      expect(auth_index).to be < set_resource_index
    end
  end

  describe 'touch throttling for secret keys' do
    before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

    context 'when last_used_at is nil' do
      before { secret_api_key.update_column(:last_used_at, nil) }

      it 'enqueues MarkAsUsed' do
        expect { get :index, as: :json }
          .to have_enqueued_job(Spree::ApiKeys::MarkAsUsed).with(secret_api_key.id, instance_of(ActiveSupport::TimeWithZone))
      end
    end

    context 'when last_used_at is older than 1 hour' do
      before { secret_api_key.update_column(:last_used_at, 2.hours.ago) }

      it 'enqueues MarkAsUsed' do
        expect { get :index, as: :json }
          .to have_enqueued_job(Spree::ApiKeys::MarkAsUsed).with(secret_api_key.id, instance_of(ActiveSupport::TimeWithZone))
      end
    end

    context 'when last_used_at is within the last hour' do
      before { secret_api_key.update_column(:last_used_at, 30.minutes.ago) }

      it 'does not enqueue MarkAsUsed' do
        expect { get :index, as: :json }.not_to have_enqueued_job(Spree::ApiKeys::MarkAsUsed)
      end
    end
  end

  describe 'response headers' do
    before { request.headers['X-Spree-Api-Key'] = secret_api_key.plaintext_token }

    it 'sets Cache-Control: private, no-store on admin responses' do
      get :index, as: :json

      expect(response.headers['Cache-Control']).to eq('private, no-store')
    end
  end
end
