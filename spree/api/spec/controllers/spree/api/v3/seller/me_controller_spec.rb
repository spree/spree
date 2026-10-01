require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::MeController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  before { request.headers['Authorization'] = "Bearer #{token}" }

  # Same serializer-key bug as the login endpoint: this used to raise.
  it 'answers before a seller is chosen' do
    get :show, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['user']['email']).to eq(seller_user.email)
    expect(json_response['sellers'].pluck('id')).to eq([seller.prefixed_id])
  end

  # Capability is per seller, so there is no meaningful answer spanning all of
  # them — the panel names one and asks again.
  it 'reports no permissions until a seller is named' do
    get :show, as: :json

    expect(json_response['permission_keys']).to eq([])
  end

  it 'reports the seeded seller permissions once one is named' do
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id

    get :show, as: :json

    expect(json_response['permission_keys']).to include('write_seller_profile', 'write_products')
  end

  # The panel's `<Can>` reads CanCanCan rules, not keys — same code as the
  # operator's dashboard. Sending only keys left every `<Can>` answering false
  # on the seller panel, silently.
  it 'serializes CanCanCan rules so the panel can gate on them' do
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id

    get :show, as: :json

    rules = json_response['permissions']
    expect(rules).to be_present
    expect(rules).to include(
      a_hash_including('allow' => true, 'subjects' => include('Spree::Product'))
    )
  end

  it 'serializes no rules until a seller is named' do
    get :show, as: :json

    expect(json_response['permissions']).to eq([])
  end

  describe 'PATCH #update' do
    subject { patch :update, params: params, as: :json }

    context 'with a name' do
      let(:params) { { first_name: 'Ada', last_name: 'Lovelace' } }

      it 'persists the name and returns it' do
        subject

        expect(response).to have_http_status(:ok)
        expect(json_response['user']['full_name']).to eq('Ada Lovelace')
        expect(seller_user.reload.first_name).to eq('Ada')
      end
    end

    # An emptied field is how a person removes a name they once gave: the
    # model normalizes blank to nil, so the panel sends the empty string
    # rather than omitting the field.
    context 'with a blank name' do
      before { seller_user.update!(first_name: 'Ada', last_name: 'Lovelace') }

      let(:params) { { first_name: '', last_name: '' } }

      it 'clears it' do
        subject

        expect(response).to have_http_status(:ok)
        expect(seller_user.reload.first_name).to be_nil
        expect(json_response['user']['full_name']).to be_nil
      end
    end

    # The panel language is a client concern — the seller panel ships its own
    # locale bundles — so the API stores whatever code it is sent.
    context 'with a locale code' do
      let(:params) { { selected_locale: 'pl' } }

      it 'persists the locale' do
        subject

        expect(response).to have_http_status(:ok)
        expect(json_response['user']['selected_locale']).to eq('pl')
        expect(seller_user.reload.selected_locale).to eq('pl')
      end
    end

    # The account is the person's own, so it answers before a seller is named
    # — the same exemption `show` relies on.
    it 'updates before a seller is chosen' do
      patch :update, params: { first_name: 'Grace' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller_user.reload.first_name).to eq('Grace')
    end

    # One photo, used both as a fresh upload and as the already-attached
    # avatar the clear case removes.
    let(:image_attributes) do
      {
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'avatar.jpg',
        content_type: 'image/jpeg'
      }
    end

    context 'with an avatar signed id' do
      let(:blob) { ActiveStorage::Blob.create_and_upload!(**image_attributes) }
      let(:params) { { avatar: blob.signed_id } }

      it 'attaches the avatar and returns its url' do
        subject

        expect(response).to have_http_status(:ok)
        expect(seller_user.reload.avatar).to be_attached
        expect(json_response['user']['avatar_url']).to be_present
      end
    end

    context 'with a non-image avatar' do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
          filename: 'avatar.svg',
          content_type: 'image/svg+xml'
        )
      end
      let(:params) { { avatar: blob.signed_id } }

      it 'rejects the upload with a validation error' do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(seller_user.reload.avatar).not_to be_attached
      end
    end

    context 'clearing the avatar' do
      before { seller_user.avatar.attach(**image_attributes) }
      let(:params) { { avatar: nil } }

      it 'purges the avatar' do
        subject

        expect(response).to have_http_status(:ok)
        expect(seller_user.reload.avatar).not_to be_attached
        expect(json_response['user']['avatar_url']).to be_nil
      end
    end

    # A seller writes their own account and nothing else through it — the
    # marketplace decides which sellers they may act for.
    context 'with an attribute the endpoint does not accept' do
      let(:params) { { first_name: 'Ada', email: 'someone-else@example.com' } }

      it 'ignores it' do
        subject

        expect(response).to have_http_status(:ok)
        expect(seller_user.reload.email).not_to eq('someone-else@example.com')
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        patch :update, params: { first_name: 'Ada' }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
