require 'spec_helper'

# A seller's CSV import over HTTP, end to end: upload, map, process, and see
# what it produced. Also the proof of the two narrowings the pipeline applies
# to a seller's import, driven through the real endpoints rather than the row
# processor directly.
RSpec.describe 'Seller CSV import', type: :request do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[write_products]) }
  let(:owner) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user, seller_role) }
  end
  let(:headers) do
    {
      'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(
        owner, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
      )}",
      'X-Spree-Seller-Id' => seller.prefixed_id
    }
  end

  def json = JSON.parse(response.body)

  # A product row that asks to be published — which a seller may not do.
  let(:csv) do
    <<~CSV
      slug,sku,name,price,status
      seller-lamp,LAMP-1,Seller Lamp,42.00,active
    CSV
  end

  let(:signed_id) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(csv), filename: 'products.csv', content_type: 'text/csv'
    ).signed_id
  end

  it 'imports the seller\'s own products as drafts' do
    post '/api/v3/seller/imports',
         params: { type: 'products', attachment: signed_id }, headers: headers
    expect(response).to have_http_status(:created)
    expect(json['status']).to eq('mapping')

    import = Spree::Import.find_by_prefix_id(json['id'])
    expect(import.owner).to eq(seller)

    # Columns are auto-assigned from the CSV headers, so mapping completes with
    # no assignments of its own. Run the row pipeline in-process so the
    # assertions below read what it actually wrote — the dispatcher fans out
    # across several jobs, which `perform_enqueued_jobs` does not follow.
    import.update!(preferred_inline: true)

    patch "/api/v3/seller/imports/#{import.prefixed_id}/complete_mapping", headers: headers
    expect(response).to have_http_status(:ok)

    product = seller.products.find_by(slug: 'seller-lamp')
    expect(product).to be_present
    expect(product.name).to eq('Seller Lamp')
    # The CSV asked for `active`; only a review can grant that.
    expect(product.status).to eq('draft')
  end

  # A seller's staff hold their roles on the seller, never on the store, so an
  # ability resolved against the store compiles no rules and every product
  # lookup comes back empty — which reads as "not found" and tries to create a
  # second product on a slug that is already taken. Re-importing is the normal
  # way a catalog is maintained, so this is the path that has to work.
  it 'updates a product it already imported' do
    existing = create(:product, slug: 'seller-lamp', name: 'Original',
                                seller: seller, store: store)

    post '/api/v3/seller/imports',
         params: { type: 'products', attachment: signed_id }, headers: headers
    import = Spree::Import.find_by_prefix_id(json['id'])
    import.update!(preferred_inline: true)
    patch "/api/v3/seller/imports/#{import.prefixed_id}/complete_mapping", headers: headers

    expect(import.reload.rows.pluck(:status)).to all(eq('completed'))
    expect(existing.reload.name).to eq('Seller Lamp')
    expect(Spree::Product.where(slug: 'seller-lamp').count).to eq(1)
  end

  it 'imports a product with variants' do
    # The shape `db/sample_data/products.csv` uses: a product header row with
    # no options, then one row per variant.
    variant_csv = <<~CSV
      slug,sku,name,price,option1_name,option1_value
      seller-tee,TEE,Seller Tee,20.00,,
      seller-tee,TEE-S,,20.00,Size,Small
      seller-tee,TEE-L,,20.00,Size,Large
    CSV
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(variant_csv), filename: 'variants.csv', content_type: 'text/csv'
    )

    post '/api/v3/seller/imports',
         params: { type: 'products', attachment: blob.signed_id }, headers: headers
    import = Spree::Import.find_by_prefix_id(json['id'])
    import.update!(preferred_inline: true)
    patch "/api/v3/seller/imports/#{import.prefixed_id}/complete_mapping", headers: headers

    expect(import.reload.rows.pluck(:status)).to all(eq('completed'))
    product = seller.products.find_by(slug: 'seller-tee')
    expect(product.variants.map(&:sku)).to contain_exactly('TEE-S', 'TEE-L')
  end

  it 'refuses an import type that is not a seller\'s to run' do
    post '/api/v3/seller/imports',
         params: { type: 'customers', attachment: signed_id }, headers: headers

    expect(response).not_to have_http_status(:created)
  end

  it "never reaches another seller's catalog" do
    other_seller = create(:seller, :approved, store: store)
    theirs = create(:product, slug: 'seller-lamp', name: 'Their Lamp',
                              seller: other_seller, store: store)

    post '/api/v3/seller/imports',
         params: { type: 'products', attachment: signed_id }, headers: headers
    import = Spree::Import.find_by_prefix_id(json['id'])
    import.update!(preferred_inline: true)
    patch "/api/v3/seller/imports/#{import.prefixed_id}/complete_mapping", headers: headers

    expect(theirs.reload.name).to eq('Their Lamp')
    expect(theirs.reload.seller).to eq(other_seller)
  end
end
