require 'spec_helper'

RSpec.describe Spree::PackageType, type: :model do
  let(:store) { @default_store }

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
