require 'spec_helper'

# The variant side of the shared catalog: which seller sells a variant, how
# they ship it, and what those two answers change about SKUs and stock.
# docs/plans/6.0-multi-vendor-marketplace.md, Decision 11.
describe Spree::Variant, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }

  describe 'seller — two modes that never mix' do
    let(:owned) { create(:product, store: store, seller: seller) }
    let(:master) { create(:product, store: store) }

    # Owned product: every variant is the product's seller's, by definition.
    it 'answers the product\'s seller on an owned product' do
      variant = create(:variant, product: owned)

      expect(variant.resolved_seller).to eq(seller)
      expect(variant.resolved_seller_id).to eq(seller.id)
      expect(variant.seller_id).to be_nil
    end

    # No other seller can create a variant on an owned product, so a value
    # written there carries no meaning and is dropped, not stored.
    it 'blanks a seller written onto a variant of an owned product' do
      variant = create(:variant, product: owned, seller: other_seller)

      expect(variant.reload.seller_id).to be_nil
      expect(variant.resolved_seller).to eq(seller)
    end

    # Master product: the shared catalog, the only place the row's own
    # seller means anything.
    it 'answers the row\'s own seller on a master product' do
      mine = create(:variant, product: master, seller: seller)
      theirs = create(:variant, product: master, seller: other_seller)

      expect(mine.resolved_seller).to eq(seller)
      expect(theirs.resolved_seller).to eq(other_seller)
      expect(master.reload.variants).to include(mine, theirs)
    end

    it 'is first-party on a master row with no seller' do
      variant = create(:variant, product: master)

      expect(variant.resolved_seller).to be_nil
      expect(variant.resolved_seller_id).to be_nil
    end

    # The whole reason the resolved answer is one field on the API: a client
    # that reads it and writes it straight back must change nothing.
    it 'survives a read-then-write round trip on an owned product unchanged' do
      variant = create(:variant, product: owned)
      read_back = variant.resolved_seller_id

      variant.update!(seller_id: read_back)

      expect(variant.reload.seller_id).to be_nil
      expect(variant.resolved_seller_id).to eq(seller.id)
    end

    it 'refuses a seller from another store on a master product' do
      foreign = create(:seller, store: create(:store))
      variant = build(:variant, product: master, seller: foreign)

      expect(variant).not_to be_valid
      expect(variant.errors[:seller]).to be_present
    end
  end

  describe 'when the seller is destroyed' do
    let(:product) { create(:product, store: store) }

    # A variant left pointing at a departed seller reads as first-party to the
    # buy box (the paranoid scope hides the row) while its id says otherwise.
    it 'releases the variant, so it does not stay attributed to nobody' do
      variant = create(:variant, product: product, seller: seller)

      seller.destroy!

      expect(variant.reload[:seller_id]).to be_nil
      expect(variant.seller_id).to be_nil
      expect(variant.seller).to be_nil
    end
  end

  describe 'delivery profile — the same two modes' do
    let(:product_profile) { create(:delivery_profile, store: store) }
    let(:row_profile) { create(:delivery_profile, store: store) }
    let(:owned) { create(:product, store: store, seller: seller, delivery_profile: product_profile) }
    let(:master) { create(:product, store: store, delivery_profile: product_profile) }

    it 'ships as the product does on an owned product, whatever the row says' do
      variant = create(:variant, product: owned, delivery_profile: row_profile)

      expect(variant.reload.delivery_profile_id).to be_nil
      expect(variant.resolved_delivery_profile).to eq(product_profile)
    end

    it 'ships on the row\'s own profile on a master product' do
      variant = create(:variant, product: master, delivery_profile: row_profile)

      expect(variant.resolved_delivery_profile).to eq(row_profile)
      expect(variant.resolved_delivery_profile_id).to eq(row_profile.id)
    end

    it 'falls back to the master\'s profile when the row names none' do
      variant = create(:variant, product: master)

      expect(variant.resolved_delivery_profile).to eq(product_profile)
    end

    it 'refuses a profile from another store' do
      foreign = create(:delivery_profile, store: create(:store))
      variant = build(:variant, product: master, delivery_profile: foreign)

      expect(variant).not_to be_valid
      expect(variant.errors[:delivery_profile]).to be_present
    end

    it 'answers digital? from the resolved profile' do
      digital = create(:digital_delivery_profile, store: store)
      variant = create(:variant, product: master, delivery_profile: digital)

      expect(variant).to be_digital
      expect(create(:variant, product: master)).not_to be_digital
    end
  end

  describe 'SKU uniqueness' do
    let(:product) { create(:product, store: store) }
    let(:other_product) { create(:product, store: store) }

    it 'lets two sellers list the same manufacturer SKU' do
      create(:variant, product: product, seller: seller, sku: 'ABC-123')
      theirs = build(:variant, product: product, seller: other_seller, sku: 'ABC-123')

      expect(theirs).to be_valid
    end

    it 'still refuses one seller listing the same SKU twice' do
      create(:variant, product: product, seller: seller, sku: 'ABC-123')
      again = build(:variant, product: other_product, seller: seller, sku: 'ABC-123')

      expect(again).not_to be_valid
      expect(again.errors[:sku]).to be_present
    end

    it 'refuses a duplicate between first-party listings' do
      create(:variant, product: product, sku: 'ABC-123')
      again = build(:variant, product: other_product, sku: 'ABC-123')

      expect(again).not_to be_valid
    end

    it 'separates sellers who own whole products rather than merging them into first-party' do
      product.update!(seller: seller)
      other_product.update!(seller: other_seller)
      create(:variant, product: product, sku: 'ABC-123')

      expect(build(:variant, product: other_product, sku: 'ABC-123')).to be_valid
    end

    it 'lets a seller keep their own SKU on save' do
      variant = create(:variant, product: product, seller: seller, sku: 'ABC-123')

      expect(variant.update(weight: 3)).to be(true)
    end
  end

  describe '.for_seller' do
    let(:product) { create(:product, store: store) }
    let(:owned_product) { create(:product, store: store, seller: seller) }

    it 'finds variants by their own seller' do
      mine = create(:variant, product: product, seller: seller)
      create(:variant, product: product, seller: other_seller)

      expect(described_class.for_seller(seller)).to include(mine)
      expect(described_class.for_seller(seller).count).to eq(1)
    end

    it 'finds variants whose seller comes from the product' do
      inherited = owned_product.variants.first

      expect(described_class.for_seller(seller)).to include(inherited)
    end

    # Spree::Export probes for this scope by name and hands it a Seller
    # record, so the record form is a contract rather than a convenience.
    it 'accepts a seller record as well as an id' do
      mine = create(:variant, product: product, seller: seller)

      expect(described_class.for_seller(seller)).to include(mine)
      expect(described_class.for_seller(seller.id)).to include(mine)
    end

    # The raw columns must not be filterable: they would match only variants
    # carrying their own seller, silently missing every one that inherits it
    # from the product — which on a single-owner catalog is all of them.
    it 'is the way to filter by seller; the raw columns are not exposed' do
      expect(described_class.whitelisted_ransackable_attributes).not_to include('seller_id')
      expect(described_class.whitelisted_ransackable_attributes).not_to include('delivery_profile_id')
    end

    it 'selects first-party listings when given nil' do
      first_party = create(:variant, product: product)
      create(:variant, product: product, seller: seller)

      expect(described_class.for_seller(nil)).to include(first_party)
      expect(described_class.for_seller(nil)).not_to include(owned_product.variants.first)
    end
  end
end
