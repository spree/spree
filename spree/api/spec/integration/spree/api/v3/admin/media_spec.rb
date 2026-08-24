# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Media Library API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, store: store) }
  let!(:media) { create(:image, viewable: product, alt: 'Front view') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/media' do
    get 'List media' do
      tags 'Media'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns every file in the store's media library, whether or not it has
        been placed on a product. Filter with `q[unattached]=true` for files not
        yet in use, `q[media_type_eq]` for images or video, and
        `q[filename_cont]` to search by file name.
      DESC
      admin_scope :read, :media

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'

      response '200', 'media found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Media')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Upload a file to the library' do
      tags 'Media'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a file to the library without placing it on anything. Upload the
        file first through the direct-upload endpoint, then send the signed id
        here. Put the file on a product by posting to that product's media with
        this record's id as `source_media_id`.
      DESC
      admin_scope :write, :media

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          signed_id: { type: :string, description: 'Direct-upload signed id for the file.' },
          alt: { type: :string, example: 'Folded on a table' },
          media_type: { type: :string, enum: %w[image video external_video], example: 'image' },
          external_video_url: { type: :string, description: 'YouTube or Vimeo link, for an external video.' }
        }
      }

      response '201', 'file added' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(
            io: File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
            filename: 'library-upload.jpg'
          )
        end
        let(:body) { { signed_id: blob.signed_id, alt: 'Folded on a table' } }

        schema SwaggerSchemaHelpers.ref('Media')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['attached']).to be(false)
        end
      end
    end
  end

  path '/api/v3/admin/media/{id}/usage' do
    parameter name: :id, in: :path, type: :string, description: 'Media ID'

    get 'Where a file is used' do
      tags 'Media'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Lists everywhere this file appears: products it is placed on, image
        fields that picked it, and descriptions embedding it. Reusing a file
        shares it rather than copying it, so deleting one placement can leave
        others pointing at the same file — check this first.

        Description matches are best-effort: an embedded image is a plain URL
        with nothing recording it, so treat an empty result as "nothing found",
        not proof the file is unused.
      DESC
      admin_scope :read, :media

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'usage found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { media.prefixed_id }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       kind: { type: :string, enum: %w[media attachment rich_text] },
                       name: { type: :string, nullable: true },
                       owner_type: { type: :string },
                       owner_id: { type: :string, nullable: true },
                       field: { type: :string, nullable: true }
                     }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end

  path '/api/v3/admin/products/{product_id}/media' do
    parameter name: :product_id, in: :path, type: :string, description: 'Product ID'

    post 'Place a library file on a product' do
      tags 'Media'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Puts a file that is already in the library onto this product. The new
        record shares the source's file rather than copying it, so nothing is
        uploaded and no image is reprocessed; it carries its own alt text,
        position and variant links from here on.
      DESC
      admin_scope :write, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          source_media_id: { type: :string, description: 'A media record already in the library.' },
          alt: { type: :string, example: 'Front view' },
          position: { type: :integer, example: 1 }
        },
        required: %w[source_media_id]
      }

      response '201', 'file placed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:target) { create(:product, store: store) }
        let(:product_id) { target.prefixed_id }
        let(:body) { { source_media_id: media.prefixed_id, alt: 'Front view' } }

        schema SwaggerSchemaHelpers.ref('Media')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['alt']).to eq('Front view')
        end
      end
    end
  end
end
