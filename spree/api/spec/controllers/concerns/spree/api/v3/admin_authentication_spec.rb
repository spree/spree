require 'spec_helper'

# Covers the +Spree::Api::V3::AdminAuthentication+ concern: secret API key
# extraction, cross-store rejection, the ability resolution that flows from
# +current_api_key+, and the callback ordering invariant that +authenticate_admin!+
# fires before +set_resource+ so +scope+'s +accessible_by(current_ability, …)+
# sees the post-authentication ability (not the unauthenticated fallback that
# previously returned nothing and surfaced as 404 on +show+/+update+/+destroy+).
#
# Uses +TaxCategoriesController+ as a representative Admin::ResourceController
# — the same mechanic applies to every admin endpoint via the shared base class.
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

  describe 'auth ordering — +authenticate_admin!+ runs before +set_resource+' do
    # Regression: +set_resource+ used to run before +authenticate_admin!+
    # because Rails appends included-module +before_action+ callbacks at the
    # end of the chain. With API-key-only auth, +current_ability+ fell back
    # to an unauthenticated +Spree::Ability+ — which has +:read+ on
    # +Spree::Product+ (so GET show happened to work) but no +:update+ /
    # +:destroy+ permission and no permission at all on resources the default
    # ability doesn't grant (e.g. +Spree::Channel+, +Spree::TaxCategory+).
    # +scope.accessible_by(ability, …)+ returned no rows, so
    # +find_by_prefix_id!+ raised +RecordNotFound+ → 404 on the four affected
    # paths.
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
