require 'spec_helper'

RSpec.describe Spree::PackageType, type: :model do
  let(:store) { @default_store }
  let(:seller) { create(:seller, store: store) }

  describe 'validations' do
    it 'refuses a kind outside the vocabulary' do
      package_type = build(:package_type, kind: 'crate')

      expect(package_type).not_to be_valid
      expect(package_type.errors[:kind]).to be_present
    end

    it 'refuses a duplicate name within the store' do
      create(:package_type, store: store, name: 'Master carton')
      duplicate = build(:package_type, store: store, name: 'Master carton')

      expect(duplicate).not_to be_valid
    end

    it 'allows the same name in a different store' do
      create(:package_type, store: store, name: 'Master carton')
      other = build(:package_type, store: create(:store), name: 'Master carton')

      expect(other).to be_valid
    end

    # Each owner names their own packaging: a seller calling their carton
    # what the marketplace calls theirs is not a collision.
    it 'allows a seller the name the marketplace already uses' do
      create(:package_type, store: store, name: 'Master carton')
      sellers_own = build(:package_type, store: store, seller: seller, name: 'Master carton')

      expect(sellers_own).to be_valid
    end

    it 'refuses a duplicate name within one seller' do
      create(:package_type, store: store, seller: seller, name: 'Master carton')
      duplicate = build(:package_type, store: store, seller: seller, name: 'Master carton')

      expect(duplicate).not_to be_valid
    end

    it 'allows two sellers the same name' do
      create(:package_type, store: store, seller: seller, name: 'Master carton')
      other = build(:package_type, store: store, seller: create(:seller, store: store), name: 'Master carton')

      expect(other).to be_valid
    end
  end

  describe 'ownership' do
    let!(:marketplace_box) { create(:package_type, store: store) }
    let!(:sellers_box) { create(:package_type, store: store, seller: seller) }
    let!(:other_sellers_box) { create(:package_type, store: store, seller: create(:seller, store: store)) }

    it 'reads the marketplace’s own rows' do
      expect(described_class.first_party).to contain_exactly(marketplace_box)
    end

    it 'reads one seller’s rows' do
      expect(described_class.for_seller(seller)).to contain_exactly(sellers_box)
    end

    it 'takes an id as well as a record' do
      expect(described_class.for_seller(seller.id)).to contain_exactly(sellers_box)
    end

    # A seller packs into their own packaging and the marketplace's shared
    # vocabulary, never another seller's.
    it 'offers a seller their own rows and the marketplace’s' do
      expect(described_class.available_to_seller(seller)).to contain_exactly(marketplace_box, sellers_box)
    end

    it 'offers the operator the marketplace’s rows alone' do
      expect(described_class.available_to_seller(nil)).to contain_exactly(marketplace_box)
    end

    # A nil seller_id IS the marketplace's row, so releasing a departed
    # seller's rows would hand the operator a second default box.
    it 'keeps a departed seller’s rows pointing at them' do
      seller.destroy

      expect(sellers_box.reload.seller_id).to eq(seller.id)
      expect(sellers_box.seller).to eq(seller)
    end
  end

  describe 'the store default' do
    it 'demotes the previous default so only one survives' do
      first = create(:package_type, store: store, default: true)
      second = create(:package_type, store: store, default: true)

      expect(first.reload).not_to be_default
      expect(second.reload).to be_default
      expect(store.default_package_type).to eq(second)
    end

    it 'leaves another store default alone' do
      other_store = create(:store)
      other_default = create(:package_type, store: other_store, default: true)
      create(:package_type, store: store, default: true)

      expect(other_default.reload).to be_default
    end

    # The operator holds one default box and each seller holds their own, so
    # promoting a seller's box must not take the marketplace's away.
    it 'leaves the marketplace default alone when a seller names theirs' do
      marketplace_default = create(:package_type, store: store, default: true)
      sellers_default = create(:package_type, store: store, seller: seller, default: true)

      expect(marketplace_default.reload).to be_default
      expect(sellers_default.reload).to be_default
      expect(store.reload.default_package_type).to eq(marketplace_default)
      expect(seller.reload.default_package_type).to eq(sellers_default)
    end

    it 'demotes only the same seller’s previous default' do
      first = create(:package_type, store: store, seller: seller, default: true)
      second = create(:package_type, store: store, seller: seller, default: true)
      other_seller = create(:seller, store: store)
      other_sellers_default = create(:package_type, store: store, seller: other_seller, default: true)

      expect(first.reload).not_to be_default
      expect(second.reload).to be_default
      expect(other_sellers_default.reload).to be_default
    end

    it 'reads the marketplace’s box through the store, never a seller’s' do
      sellers_only_default = create(:package_type, store: store, seller: seller, default: true)

      expect(store.reload.default_package_type).to be_nil
      expect(seller.reload.default_package_type).to eq(sellers_only_default)
    end
  end

  describe '#volume' do
    it 'reports cubic meters from the recorded unit' do
      package_type = build(:package_type, length: 100, width: 100, height: 100, dimensions_unit: 'cm')

      expect(package_type.volume).to eq(BigDecimal('1'))
    end

    it 'is nil until every side is measured' do
      expect(build(:package_type, length: 100, width: 100, height: nil).volume).to be_nil
    end
  end

  describe '#dimensions_unit' do
    it 'reads centimeters on a metric store' do
      stub_store_preferences(store, unit_system: 'metric')

      expect(build(:package_type, store: store, dimensions_unit: nil).dimensions_unit).to eq('cm')
    end

    it 'reads inches on an imperial store' do
      stub_store_preferences(store, unit_system: 'imperial')

      expect(build(:package_type, store: store, dimensions_unit: nil).dimensions_unit).to eq('in')
    end
  end

  describe 'reading geometry in another unit' do
    subject(:package_type) do
      build(:package_type, length: 30.48, width: 22.86, height: 10.16,
                           dimensions_unit: 'cm', weight: 1, weight_unit: 'kg')
    end

    it 'converts the sides' do
      expect(package_type.dimensions_in('in')).to eq(length: 12.0, width: 9.0, height: 4.0)
    end

    it 'converts the tare' do
      expect(package_type.weight_in('lb')).to be_within(0.001).of(2.2046)
    end

    it 'has no dimensions until every side is recorded' do
      package_type.height = nil

      expect(package_type.dimensions_in('cm')).to be_nil
    end

    it 'reads an unrecorded tare as nothing rather than nil' do
      expect(build(:package_type, weight: nil).weight_in('kg')).to eq(0)
    end
  end

  describe 'giving up the default' do
    # Clearing the flag leaves the store with no box at all, which is the
    # same silent loss as deleting it.
    it 'refuses to turn the flag off on the only default' do
      package_type = create(:package_type, store: store, default: true)

      expect(package_type.update(default: false)).to be(false)
      expect(package_type.errors[:default]).to be_present
      expect(store.reload.default_package_type).to eq(package_type)
    end

    it 'allows it once another row holds the flag' do
      first = create(:package_type, store: store, default: true)
      create(:package_type, store: store, default: true)

      expect(first.reload).not_to be_default
    end

    # The marketplace's box is not a replacement for the seller's: it is a
    # different owner's row, so it cannot stand in as "another default".
    it 'refuses a seller’s only default even when the marketplace has one' do
      create(:package_type, store: store, default: true)
      sellers_default = create(:package_type, store: store, seller: seller, default: true)

      expect(sellers_default.update(default: false)).to be(false)
      expect(sellers_default.errors[:default]).to be_present
    end
  end

  describe 'changing kind' do
    # The variant validation only runs when the variant is saved, so a carton
    # that turned into a pallet would leave its products pointing at a row
    # they could no longer choose.
    it 'refuses to stop being a carton while products are packed into it' do
      carton = create(:carton_package_type, store: store)
      create(:variant, carton_package_type: carton)

      expect(carton.update(kind: 'pallet')).to be(false)
      expect(carton.errors[:kind]).to be_present
      expect(carton.reload.kind).to eq('carton')
    end

    it 'allows the change once nothing is packed into it' do
      carton = create(:carton_package_type, store: store)

      expect(carton.update(kind: 'pallet')).to be(true)
    end

    it 'leaves other edits to a carton in use alone' do
      carton = create(:carton_package_type, store: store)
      create(:variant, carton_package_type: carton)

      expect(carton.update(name: 'Renamed carton', length: 50)).to be(true)
    end
  end

  describe 'deletion' do
    # Deleting it would leave every quote with no tare and no dimensions,
    # which under-prices bulky shipments with nothing to notice.
    it 'refuses the store default' do
      package_type = create(:package_type, store: store, default: true)

      expect(package_type.destroy).to be_falsey
      expect(package_type.errors[:base]).to be_present
      expect(store.reload.default_package_type).to eq(package_type)
    end

    # Refusing here would abort the store's own destroy and strand the row.
    it 'goes with the store it belongs to' do
      other_store = create(:store)
      package_type = create(:package_type, store: other_store, default: true)

      expect { other_store.destroy }.not_to raise_error
      expect(Spree::PackageType.where(id: package_type.id)).not_to exist
    end

    it 'refuses while a variant is packed into it' do
      carton = create(:carton_package_type, store: store)
      create(:variant, carton_package_type: carton)

      expect(carton.destroy).to be_falsey
      expect(carton.errors[:base]).to be_present
    end
  end
end
