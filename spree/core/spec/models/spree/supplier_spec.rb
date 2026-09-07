require 'spec_helper'

module Spree
  describe Supplier, type: :model do
    let(:store) { Spree::Store.default }

    it_behaves_like 'metadata'
    it_behaves_like 'lifecycle events'

    describe 'validations' do
      it 'requires a name unique within the store' do
        create(:supplier, store: store, name: 'Acme Wholesale')

        expect(build(:supplier, store: store, name: 'Acme Wholesale')).to be_invalid
        expect(build(:supplier, store: create(:store), name: 'Acme Wholesale')).to be_valid
      end

      # A soft-deleted supplier keeps its name. The unique index cannot be
      # narrowed to live rows on every database Spree supports, so the
      # validation matches the index — and a merchant gets a message rather
      # than the constraint violation a narrowed validation would let through.
      it 'keeps the name reserved after the supplier is deleted' do
        create(:supplier, store: store, name: 'Acme Wholesale').destroy

        reused = build(:supplier, store: store, name: 'Acme Wholesale')
        expect(reused).to be_invalid
        expect(reused.errors[:name]).to be_present
      end

      it 'refuses an email that is not one' do
        expect(build(:supplier, email: 'not-an-email')).to be_invalid
        expect(build(:supplier, email: nil)).to be_valid
      end
    end

    describe 'normalization' do
      it 'stores the email lower-cased and trimmed' do
        supplier = create(:supplier, email: '  Sales@Acme.test ')

        expect(supplier.email).to eq('sales@acme.test')
      end
    end

    describe '#address' do
      it 'builds an unsaved address from its own columns' do
        supplier = build(:supplier, :with_address, name: 'Acme Wholesale')

        expect(supplier).to be_postable
        expect(supplier.address).to have_attributes(
          company: 'Acme Wholesale', city: 'Brooklyn', country_code: 'US', postal_code: '11201'
        )
        expect(supplier.address).not_to be_persisted
      end

      # Every caller needs the guard: a blank supplier answers with a blank
      # address that would otherwise read as configured.
      it 'is not postable without a street, a city and a country' do
        expect(build(:supplier)).not_to be_postable
      end
    end

    describe 'deleting' do
      it 'refuses while purchase orders still point at it' do
        supplier = create(:supplier, store: store)
        create(:purchase_order, store: store, supplier: supplier)

        expect(supplier.destroy).to be false
        expect(supplier.errors[:base]).to be_present
      end
    end
  end
end
