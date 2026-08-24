require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::MediaLibraryController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product) }
  let!(:placed) { create(:image, viewable: product) }
  let!(:unplaced) { create(:image, viewable: nil) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists placed and unplaced files alike' do
      get :index, as: :json

      ids = json_response['data'].map { |media| media['id'] }
      expect(ids).to include(placed.prefixed_id, unplaced.prefixed_id)
    end

    it 'reports whether each file is placed' do
      get :index, as: :json

      states = json_response['data'].to_h { |media| [media['id'], media['attached']] }
      expect(states[placed.prefixed_id]).to be(true)
      expect(states[unplaced.prefixed_id]).to be(false)
    end

    it 'reports the file facts the library grid shows' do
      get :index, as: :json

      media = json_response['data'].find { |candidate| candidate['id'] == placed.prefixed_id }
      expect(media['filename']).to eq('thinking-cat.jpg')
      expect(media['content_type']).to eq('image/jpeg')
      expect(media['byte_size']).to be_positive
    end

    # Reuse shares the file rather than copying it, so the same picture on two
    # products is two rows. The library shows files, not placements.
    context 'with the same file placed on two products' do
      let!(:copy) { placed.duplicate_for(create(:product)).tap(&:save!) }

      it 'lists the file once' do
        get :index, as: :json

        ids = json_response['data'].map { |media| media['id'] }
        expect(ids).to include(copy.prefixed_id)
        expect(ids).not_to include(placed.prefixed_id)
      end

      # The row the listing hides is still a real record — a client holding its
      # id (a product's gallery links to it) must still be able to act on it.
      it 'still resolves the hidden row directly' do
        get :show, params: { id: placed.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(placed.prefixed_id)
      end

      # Addressable, but not deletable while the file is in use — the library
      # destroy deletes files, and this file is on two products.
      it 'still refuses deleting the hidden row while the file is in use' do
        expect {
          delete :destroy, params: { id: placed.prefixed_id }, as: :json
        }.not_to change(Spree::Media, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with media belonging to another store' do
      let(:other_store) { create(:store) }
      let!(:foreign) { create(:image, viewable: create(:product, store: other_store)) }

      it 'lists only this store' do
        get :index, as: :json

        ids = json_response['data'].map { |media| media['id'] }
        expect(ids).not_to include(foreign.prefixed_id)
      end
    end

    describe 'filtering' do
      it 'narrows to unplaced files' do
        get :index, params: { q: { unattached: true } }, as: :json

        ids = json_response['data'].map { |media| media['id'] }
        expect(ids).to include(unplaced.prefixed_id)
        expect(ids).not_to include(placed.prefixed_id)
      end

      it 'searches by filename' do
        get :index, params: { q: { filename_cont: 'thinking' } }, as: :json

        expect(json_response['data']).to be_present
      end

      it 'narrows by media type' do
        video = create(:video_media, viewable: nil)

        get :index, params: { q: { media_type_eq: 'video' } }, as: :json

        ids = json_response['data'].map { |media| media['id'] }
        expect(ids).to eq([video.prefixed_id])
      end
    end
  end

  describe 'POST #create' do
    let(:signed_id) do
      ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
        filename: 'library-upload.jpg'
      ).signed_id
    end

    it 'uploads a file with nowhere to put it yet' do
      expect {
        post :create, params: { signed_id: signed_id }, as: :json
      }.to change(Spree::Media, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['attached']).to be(false)
      expect(Spree::Media.last.store).to eq(store)
    end

    # The import job needs a viewable to write onto, and a library row has none.
    it 'refuses a URL import, which needs a product' do
      post :create, params: { url: 'https://example.com/a.png' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    # A video's still: the library edits it in place, where the product gallery
    # carries it on the surrounding form.
    it 'attaches a poster to a video' do
      video = create(:video_media, viewable: nil)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
        filename: 'poster.jpg'
      )

      patch :update, params: { id: video.prefixed_id, poster_signed_id: blob.signed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(video.reload.poster).to be_attached
    end

    it 'drops the poster when sent blank' do
      video = create(:video_media, viewable: nil)
      video.poster.attach(
        io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
        filename: 'poster.jpg'
      )
      video.save!

      perform_enqueued_jobs do
        patch :update, params: { id: video.prefixed_id, poster_signed_id: '' }, as: :json
      end

      expect(video.reload.poster).not_to be_attached
    end
  end

  describe 'GET #usage' do
    it 'reports where the file is used' do
      other_product = create(:product, name: 'Also uses it')
      placed.duplicate_for(other_product).save!

      get :usage, params: { id: placed.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].map { |reference| reference['name'] }
      expect(names).to include('Also uses it')
    end

    it 'reports nothing for a file used nowhere else' do
      get :usage, params: { id: unplaced.prefixed_id }, as: :json

      expect(json_response['data']).to be_empty
    end

    # Reading where a file is used is reading the file. CanCanCan's `:read`
    # alias covers only index and show, so without the action mapping a
    # staffer who can view media is refused.
    context 'as staff with read access only' do
      let(:reader_role) { create(:role, name: 'Reader', permissions: %w[read_media]) }
      let(:reader) { create(:admin_user, :without_admin_role) }

      # JWT only. The shared context's headers also carry a full-scope secret
      # key, which authorizes on its own and would hide a CanCanCan refusal.
      let(:reader_jwt) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          reader, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        )
      end
      let(:headers) { { 'Authorization' => "Bearer #{reader_jwt}" } }

      before { store.add_user(reader, reader_role) }

      it 'allows reading usage' do
        get :usage, params: { id: placed.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    # The library spans products, categories and collections, so it is not a
    # product endpoint: product permissions alone must not name a category or
    # delete its image.
    context 'as staff holding only product permissions' do
      let(:products_role) { create(:role, name: 'Products', permissions: %w[read_products write_products]) }
      let(:products_user) { create(:admin_user, :without_admin_role) }
      let(:products_jwt) do
        Spree::Api::V3::TestingSupport.generate_jwt(
          products_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
        )
      end
      let(:headers) { { 'Authorization' => "Bearer #{products_jwt}" } }

      before { store.add_user(products_user, products_role) }

      it 'refuses reading where a file is used' do
        get :usage, params: { id: placed.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end

      it 'refuses listing the library' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'removes a file that is used nowhere' do
      expect {
        delete :destroy, params: { id: unplaced.prefixed_id }, as: :json
      }.to change(Spree::Media, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    # Deleting from the library means deleting the file; a file still in use is
    # refused with the places, so nothing quietly loses its image.
    it 'refuses a file that is still in use, naming the places' do
      copy = placed.duplicate_for(create(:product, name: 'Still uses it'))
      copy.save!

      expect {
        delete :destroy, params: { id: copy.prefixed_id }, as: :json
      }.not_to change(Spree::Media, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to include('Still uses it')
      expect(json_response['error']['details']['usage']).to be_an(Array)
    end

    it 'refuses deleting a file placed on a product' do
      delete :destroy, params: { id: placed.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(placed.reload).to be_persisted
    end

    # With the caller's say-so — the dashboard's confirmation — the file is
    # removed from everywhere using it in one pass.
    context 'with detach' do
      it 'removes the file from every place using it' do
        copy = placed.duplicate_for(create(:product))
        copy.save!
        category = create(:category)
        category.image.attach(placed.attachment.blob)
        category.save!

        perform_enqueued_jobs do
          delete :destroy, params: { id: placed.prefixed_id, detach: true }, as: :json
        end

        expect(response).to have_http_status(:no_content)
        expect(Spree::Media.exists?(placed.id)).to be(false)
        expect(Spree::Media.exists?(copy.id)).to be(false)
        expect(category.reload.image).not_to be_attached
        expect(product.reload.media).to be_empty
      end
    end
  end
end
