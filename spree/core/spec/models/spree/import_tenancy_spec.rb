require 'spec_helper'

# Imports and exports carry the same two axes: which marketplace the job
# belongs to, and — when a seller ran it — whose it is. A null seller means the
# operator's own, which is what lets one store-scoped list carry both.
RSpec.describe 'import and export tenancy' do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:seller) { create(:seller, store: store) }
  let(:user) { create(:admin_user) }

  describe Spree::Import do
    it 'carries both axes for a seller import' do
      import = create(:product_import, store: store, seller: seller, user: user)

      expect(import.store).to eq(store)
      expect(import.seller).to eq(seller)
    end

    it 'leaves the seller blank for the operator\'s own' do
      import = create(:product_import, store: store, user: user)

      expect(import.seller).to be_nil
      expect(Spree::Import.for_store(store).first_party).to include(import)
    end

    # The point of the change: an operator's store-scoped list includes the
    # imports their sellers ran, so a failed seller upload is debuggable
    # without impersonating them.
    it 'puts a seller\'s import in the operator\'s list' do
      mine = create(:product_import, store: store, user: user)
      theirs = create(:product_import, store: store, seller: seller, user: user)

      expect(Spree::Import.for_store(store)).to include(mine, theirs)
      expect(Spree::Import.for_store(store).for_seller(seller)).to contain_exactly(theirs)
    end

    it 'refuses a seller from another marketplace' do
      import = build(:product_import, store: other_store, seller: seller, user: user)

      expect(import).not_to be_valid
      expect(import.errors[:seller]).to be_present
    end

    # `owner` shipped in 5.6 and the v3 serializer still emits it.
    describe 'the deprecated owner bridge' do
      it 'answers the seller when one ran it' do
        import = create(:product_import, store: store, seller: seller, user: user)

        expect(import.owner).to eq(seller)
      end

      it 'answers the store otherwise' do
        expect(create(:product_import, store: store, user: user).owner).to eq(store)
      end

      it 'still accepts a seller on write' do
        import = build(:product_import, user: user)
        import.owner = seller

        expect(import.seller).to eq(seller)
        expect(import.store).to eq(store)
      end
    end
  end

  describe Spree::Export do
    # `belongs_to :seller` shipped in 5.6 with no column behind it, so this
    # raised PG::UndefinedColumn until the column landed.
    it 'can be filtered by seller' do
      expect { Spree::Export.ransack(seller_id_eq: seller.id).result.to_a }.not_to raise_error
    end

    it 'refuses a seller from another marketplace' do
      export = build(:export, store: other_store, seller: seller, user: user)

      expect(export).not_to be_valid
      expect(export.errors[:seller]).to be_present
    end

    it 'puts a seller\'s export in the operator\'s list' do
      theirs = create(:export, store: store, seller: seller, user: user)

      expect(Spree::Export.for_store(store)).to include(theirs)
    end

    # `Export#scope` has narrowed exported rows by seller since 5.6, but with
    # no column behind the association `seller` was always nil, so the line
    # never fired. The column is what lets it.
    #
    # It applies to models that answer `for_seller` — `Spree::Variant` does,
    # `Spree::Product` does not, so a product export is still store-wide. That
    # gap predates this change and is a separate decision.
    it 'narrows an export to the seller where the model supports it' do
      mine = create(:product, store: store, seller: seller).default_variant
      theirs = create(:product, store: store).default_variant
      export = create(:export, store: store, seller: seller, user: user,
                               type: 'Spree::Exports::Products')

      scoped = Spree::Variant.for_seller(seller)

      expect(export.seller).to eq(seller)
      expect(scoped).to include(mine)
      expect(scoped).not_to include(theirs)
    end
  end
end
