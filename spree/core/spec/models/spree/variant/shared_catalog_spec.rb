require 'spec_helper'

# The variant side of the shared catalog: which seller sells a variant, how
# they ship it, and what those two answers change about SKUs and stock.
# docs/plans/6.0-multi-vendor-marketplace.md, Decision 11.
describe Spree::Variant, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }
  let(:other_seller) { create(:seller, :approved, store: store) }

  describe '#seller' do
    let(:product) { create(:product, store: store) }

    it 'is the variant\'s own seller when it has one' do
      variant = create(:variant, product: product, seller: seller)

      expect(variant.seller).to eq(seller)
      expect(variant.seller_id).to eq(seller.id)
    end

    it 'falls back to the product\'s seller when the variant has none' do
      product.update!(seller: seller)
      variant = create(:variant, product: product)

      expect(variant.seller).to eq(seller)
      expect(variant.seller_id).to eq(seller.id)
    end

    it 'is nil for a first-party listing' do
      variant = create(:variant, product: product)

      expect(variant.seller).to be_nil
      expect(variant.seller_id).to be_nil
    end

    it 'lets two sellers list variants on one product' do
      mine = create(:variant, product: product, seller: seller)
      theirs = create(:variant, product: product, seller: other_seller)

      expect(product.reload.variants).to include(mine, theirs)
      expect(mine.seller).to eq(seller)
      expect(theirs.seller).to eq(other_seller)
    end

    it 'refuses a seller from another store' do
      foreign = create(:seller, store: create(:store))
      variant = build(:variant, product: product, seller: foreign)

      expect(variant).not_to be_valid
      expect(variant.errors[:seller]).to be_present
    end

    # The resolved reader memoizes, so a write has to drop the memo. Reading
    # first is what makes this bite: the inherited seller is truthy, so the
    # memo sticks and the reader keeps naming the old seller until save —
    # and the SKU check reads it.
    it 'does not keep answering with the inherited seller after a reassignment' do
      product.update!(seller: seller)
      variant = create(:variant, product: product)
      expect(variant.seller_id).to eq(seller.id)

      variant.seller = other_seller

      expect(variant.seller_id).to eq(other_seller.id)
      expect(variant.seller).to eq(other_seller)
    end

    it 'does not keep answering with the inherited seller after an id write' do
      product.update!(seller: seller)
      variant = create(:variant, product: product)
      expect(variant.seller_id).to eq(seller.id)

      variant.seller_id = other_seller.id

      expect(variant.seller_id).to eq(other_seller.id)
      expect(variant.seller).to eq(other_seller)
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

  describe '#delivery_profile' do
    let(:product_profile) { create(:delivery_profile, store: store) }
    let(:variant_profile) { create(:delivery_profile, store: store) }
    let(:product) { create(:product, store: store, delivery_profile: product_profile) }

    it 'falls back to the product\'s profile' do
      variant = create(:variant, product: product)

      expect(variant.delivery_profile).to eq(product_profile)
      expect(variant.delivery_profile_id).to eq(product_profile.id)
    end

    it 'prefers its own override' do
      variant = create(:variant, product: product, delivery_profile: variant_profile)

      expect(variant.delivery_profile).to eq(variant_profile)
      expect(variant.delivery_profile_id).to eq(variant_profile.id)
    end

    it 'refuses a profile from another store' do
      foreign = create(:delivery_profile, store: create(:store))
      variant = build(:variant, product: product, delivery_profile: foreign)

      expect(variant).not_to be_valid
      expect(variant.errors[:delivery_profile]).to be_present
    end

    # The resolved profile is what the variant ships on; the override is what
    # a client may write. Reading the resolved value under the writable name
    # would freeze inheritance into an override on the first round-trip save.
    it 'separates the resolved profile from the override a client writes' do
      variant = create(:variant, product: product)

      expect(variant.delivery_profile_id).to eq(product_profile.id)
      expect(variant.own_delivery_profile_id).to be_nil

      variant.update!(own_delivery_profile_id: variant_profile.id)

      expect(variant.reload.own_delivery_profile_id).to eq(variant_profile.id)
      expect(variant.delivery_profile_id).to eq(variant_profile.id)
    end

    # The writable name has to clear the memos too, or a hook or serializer
    # reading the profile between the write and the save sees the old one.
    it 'does not keep answering with the old profile after a write through the override name' do
      variant = create(:variant, product: product)
      expect(variant.delivery_profile).to eq(product_profile)

      variant.own_delivery_profile_id = variant_profile.id

      expect(variant.delivery_profile).to eq(variant_profile)
      expect(variant.delivery_profile_id).to eq(variant_profile.id)
    end

    it 'clears the override back to inheriting when the client writes nil' do
      variant = create(:variant, product: product, delivery_profile: variant_profile)

      variant.update!(own_delivery_profile_id: nil)

      expect(variant.reload.own_delivery_profile_id).to be_nil
      expect(variant.delivery_profile_id).to eq(product_profile.id)
    end

    it 'does not keep answering with the inherited profile after a reassignment' do
      variant = create(:variant, product: product)
      expect(variant.delivery_profile).to eq(product_profile)

      variant.delivery_profile = variant_profile

      expect(variant.delivery_profile).to eq(variant_profile)
      expect(variant.delivery_profile_id).to eq(variant_profile.id)
    end

    it 'answers digital? from its own profile, not the product\'s' do
      digital = create(:digital_delivery_profile, store: store)
      variant = create(:variant, product: product, delivery_profile: digital)

      expect(variant).to be_digital
      expect(create(:variant, product: product)).not_to be_digital
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
