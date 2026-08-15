require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SetupController, type: :controller do
  render_views

  describe 'GET #show' do
    context 'when no admin user exists' do
      it 'reports setup as required' do
        get :show, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['setup_required']).to be(true)
      end
    end

    context 'when an admin user exists' do
      before { create(:admin_user) }

      it 'reports setup as not required' do
        get :show, as: :json

        expect(json_response['setup_required']).to be(false)
      end
    end
  end

  describe 'GET #countries' do
    it 'lists countries with their derived currency and official locales' do
      get :countries, as: :json

      expect(response).to have_http_status(:ok)

      countries = json_response['countries']
      switzerland = countries.find { |country| country['code'] == 'CH' }

      expect(switzerland['name']).to eq('Switzerland')
      expect(switzerland['currency']).to eq('CHF')
      expect(switzerland['locales']).to include('de', 'fr', 'it')
    end

    # Same posture as the rest of the flow: it exists only while the
    # installation is unclaimed.
    it 'is gone once an admin exists' do
      create(:admin_user)

      get :countries, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    # Read fresh, not through the memoized @default_store: the shared object
    # reloads in an after(:each) that runs inside the previous example's
    # still-open transaction, so it can carry the cleared token forward.
    let(:setup_token) { Spree::Store.default.setup_token }
    let(:valid_params) do
      {
        setup_token: setup_token,
        email: 'owner@example.com',
        password: 'Secret123!',
        password_confirmation: 'Secret123!',
        first_name: 'Olivia',
        last_name: 'Owner',
        store_name: 'My New Store',
        country_code: 'US'
      }
    end

    context 'with a valid token' do
      it 'creates the first admin, adopts the store, spends the token, and signs in' do
        expect {
          post :create, params: valid_params, as: :json
        }.to change(Spree.admin_user_class, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response['token']).to be_present
        expect(json_response['user']['email']).to eq('owner@example.com')

        user = Spree.admin_user_class.find_by(email: 'owner@example.com')
        expect(user.role_users.exists?(store: @default_store)).to be(true)
        expect(@default_store.reload.name).to eq('My New Store')
        expect(@default_store.setup_token).to be_nil
        expect(response.cookies['spree_admin_refresh_token']).to be_present
      end

      # The whole point of asking for a country: the store, its market and
      # everything shaped by geography agree on where the shop is.
      it 'provisions the store for the chosen country, deriving the currency' do
        post :create, params: valid_params.merge(country_code: 'de', locale: 'de'), as: :json

        expect(response).to have_http_status(:ok)

        store = @default_store.reload
        expect(store.default_country_code).to eq('DE')
        expect(store.default_currency).to eq('EUR')
        expect(store.default_locale).to eq('de')
        expect(store.default_market.country_codes).to eq(['DE'])
        expect(store.stock_locations.find_by(default: true).country_code).to eq('DE')
        expect(store.delivery_zones.find_by(name: 'Domestic').members.pluck(:country_code)).to eq(['DE'])
      end

      it "defaults the locale to the country's own language" do
        post :create, params: valid_params.merge(country_code: 'DE'), as: :json

        expect(response).to have_http_status(:ok)
        expect(@default_store.reload.default_locale).to eq('de')
      end

      # An unknown country is refused before the token is spent, so the
      # operator can correct the typo and try again.
      it 'refuses an unknown country and leaves the token usable' do
        post :create, params: valid_params.merge(country_code: 'ZZ'), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(@default_store.reload.setup_token).to be_present
        expect(Spree.admin_user_class.find_by(email: 'owner@example.com')).to be_nil
      end

      it 'refuses a missing country and leaves the token usable' do
        post :create, params: valid_params.except(:country_code), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(@default_store.reload.setup_token).to be_present
        expect(Spree.admin_user_class.count).to eq(0)
      end

      it 'returns 422 with field errors on invalid input' do
        post :create, params: valid_params.merge(password_confirmation: 'nope'), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(Spree.admin_user_class.count).to eq(0)
        expect(@default_store.reload.setup_token).to be_present
      end
    end

    context 'with an invalid token' do
      it 'returns 404 without creating anything' do
        post :create, params: valid_params.merge(setup_token: 'wrong'), as: :json

        expect(response).to have_http_status(:not_found)
        expect(Spree.admin_user_class.count).to eq(0)
      end
    end

    context 'when an admin already exists' do
      before { create(:admin_user) }

      it 'returns 404 even with a valid token' do
        post :create, params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(Spree.admin_user_class.count).to eq(1)
      end
    end

    context 'without a token param' do
      it 'returns 404' do
        post :create, params: valid_params.except(:setup_token), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the token is spent between the guard and the write' do
      # Simulates the concurrent-submit race: the pre-lock check passes, then
      # another request completes setup before this one takes the lock.
      it 'returns 404 and creates no second admin' do
        call_count = 0
        allow_any_instance_of(described_class).to receive(:setup_token_usable?).and_wrap_original do |original, *args|
          call_count += 1
          call_count == 1 ? original.call(*args) : false
        end

        post :create, params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(Spree.admin_user_class.count).to eq(0)
      end
    end

    context 'when the store has no token' do
      before { @default_store.update_column(:setup_token, nil) }

      it 'returns 404' do
        post :create, params: valid_params.merge(setup_token: 'anything'), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
