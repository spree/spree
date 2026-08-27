require 'spec_helper'

# A seller's CSV import runs the operator's pipeline, narrowed twice: it may
# only resolve onto that seller's own products, and what it creates is theirs
# and lands as a draft. Both narrowings live in the row processor rather than
# in a controller, because rows are processed in a background job long after
# any request scope is gone.
RSpec.describe Spree::Imports::RowProcessors::ProductVariant, 'for a seller-owned import', type: :service do
  subject { described_class.new(row) }

  let(:store) { Spree::Store.default }
  let(:seller) { create(:seller, store: store) }
  let(:other_seller) { create(:seller, store: store) }

  # A real seller's staff member: their role is held on the seller, never on
  # the store. The factory's default user is a store admin, whose blanket
  # access would hide whether the scoping below actually works.
  let(:seller_role) { create(:role, name: 'Seller', resource: seller, permissions: %w[write_products]) }
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user, seller_role) }
  end
  let(:import) { create(:product_import, store: store, seller: seller, user: seller_user) }
  let(:row) { create(:import_row, import: import, data: row_data.to_json) }
  let(:csv_row_headers) { Spree::ImportSchemas::Products.new.headers }

  before do
    Spree.import_start_mapping_workflow.call(import: import)
    # `product_type` is not auto-assigned (its CSV header differs from the
    # schema field), so map it by hand as the existing processor spec does.
    import.mappings.find_by(schema_field: 'product_type')&.update(file_column: 'product_type')
  end

  def csv_row_hash(attrs = {})
    csv_row_headers.index_with { |header| attrs[header] }
  end

  describe 'ownership' do
    let(:row_data) do
      csv_row_hash('slug' => 'denim-shirt', 'name' => 'Denim Shirt', 'price' => '62.99')
    end

    it 'stamps the seller on a product it creates' do
      product = subject.process!

      expect(product.seller).to eq(seller)
      expect(product.store).to eq(store)
    end
  end

  describe 'the status column' do
    let(:row_data) do
      csv_row_hash('slug' => 'denim-shirt', 'name' => 'Denim Shirt', 'price' => '62.99',
                   'status' => 'active')
    end

    # A seller reaches `active` only through review, so the column is ignored
    # rather than honoured — otherwise a CSV would publish to the marketplace
    # catalog with nobody having looked at it.
    it 'never lets a seller publish by uploading' do
      expect(subject.process!.status).to eq('draft')
    end

    context 'when the import is the operator\'s own' do
      let(:import) { create(:product_import, store: store) }

      it 'still honours the column' do
        expect(subject.process!.status).to eq('active')
      end
    end
  end

  describe 'reach' do
    let!(:theirs) do
      create(:product, slug: 'denim-shirt', name: 'Their Shirt', seller: other_seller, store: store)
    end

    let(:row_data) do
      csv_row_hash('slug' => 'denim-shirt', 'name' => 'Renamed By Me', 'price' => '1.00')
    end

    # The ability cannot answer this: it grants capability, never tenancy, so
    # `write_products` reaches every product in the class. Without the scope
    # narrowing, this row would resolve onto the other seller's product and
    # rename it.
    #
    # The row fails rather than creating a second product, because a slug is
    # unique per store — which is the right answer either way: the seller sees
    # a failed row naming the slug, and nobody else's listing moved.
    it "never touches another seller's product with a matching slug" do
      expect { subject.process! rescue nil }.not_to(change { theirs.reload.name })
    end

    it 'fails the row rather than editing across sellers' do
      expect { subject.process! }.to raise_error(ActiveRecord::RecordInvalid, /Slug/)
    end
  end

  # Ownership is what makes this work: SKU uniqueness is scoped to the
  # variant's resolved seller, so the seller must be on the product before its
  # variants are saved. Two sellers listing the same manufacturer part number
  # is ordinary on a marketplace.
  describe 'a SKU another seller already uses' do
    let!(:theirs) do
      create(:product, slug: 'their-lamp', seller: other_seller, store: store).tap do |product|
        product.default_variant.update!(sku: 'LAMP-1')
      end
    end

    let(:row_data) do
      csv_row_hash('slug' => 'my-lamp', 'sku' => 'LAMP-1', 'name' => 'My Lamp', 'price' => '1.00')
    end

    it 'imports without colliding' do
      variant = subject.process!

      expect(variant).to be_persisted
      expect(subject.product.seller).to eq(seller)
    end
  end

  # Filing and vocabulary are the marketplace's, not a seller's — the same
  # line the seller products endpoint draws by refusing these attributes.
  describe 'the marketplace\'s own vocabulary' do
    let(:row_data) do
      csv_row_hash('slug' => 'denim-shirt', 'name' => 'Denim Shirt', 'price' => '1.00',
                   'tags' => 'ECO, Gold', 'category1' => 'Invented Category',
                   'product_type' => 'Invented Type')
    end

    it 'creates no product type a seller could not have chosen' do
      expect { subject.process! }.not_to change(Spree::ProductType, :count)
    end

    it 'writes no tags into the store\'s vocabulary' do
      expect { subject.process! }.not_to have_enqueued_job(Spree::Imports::AssignTagsJob)
    end

    it 'files the product into no category' do
      expect { subject.process! }.not_to have_enqueued_job(Spree::Imports::CreateCategoriesJob)
    end

    context 'when the import is the operator\'s own' do
      let(:import) { create(:product_import, store: store) }

      it 'still creates the type it was given' do
        expect { subject.process! }.to change(Spree::ProductType, :count).by(1)
      end
    end
  end

  describe 'inventory' do
    let!(:seller_location) do
      create(:stock_location, seller: seller, store: store, name: "#{seller.name} warehouse",
                              default: false)
    end

    let(:row_data) do
      csv_row_hash('slug' => 'denim-shirt', 'name' => 'Denim Shirt', 'price' => '1.00',
                   'inventory_count' => '7')
    end

    # `Variant#default_stock_location` answers the *store's*, so without an
    # explicit location a seller's goods land in the marketplace's warehouse.
    it 'stocks the seller\'s own warehouse' do
      variant = subject.process!
      level = variant.stock_levels.find_by(stock_location: seller_location)

      expect(level).to be_present
      expect(level.count_on_hand).to eq(7)
    end
  end

  describe 'updating' do
    let!(:mine) do
      create(:product, slug: 'denim-shirt', name: 'Old Name', seller: seller, store: store)
    end

    let(:row_data) do
      csv_row_hash('slug' => 'denim-shirt', 'name' => 'New Name', 'price' => '1.00')
    end

    it 'updates the seller\'s own product in place' do
      product = subject.process!

      expect(product.id).to eq(mine.id)
      expect(mine.reload.name).to eq('New Name')
    end
  end
end
