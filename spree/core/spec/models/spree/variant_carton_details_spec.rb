require 'spec_helper'

RSpec.describe 'Spree::Variant carton details', type: :model do
  let(:store) { @default_store }
  let(:carton) { create(:carton_package_type, store: store, length: 40, width: 30, height: 25) }

  describe 'the carton reference' do
    it 'accepts a carton-kind package type' do
      expect(build(:variant, carton_package_type: carton)).to be_valid
    end

    # A pallet is what cartons stack on, not what a product is packed into.
    it 'refuses a package type of any other kind' do
      variant = build(:variant, carton_package_type: create(:pallet_package_type, store: store))

      expect(variant).not_to be_valid
      expect(variant.errors[:carton_package_type]).to be_present
    end
  end

  describe '#carton_volume' do
    it 'reads the geometry off the shared carton row' do
      expect(build(:variant, carton_package_type: carton).carton_volume).to eq(BigDecimal('0.03'))
    end

    # One edit to a carton size corrects every product packed in it — the
    # reason geometry is shared rather than copied onto each variant.
    it 'follows the carton when the carton is resized' do
      variant = create(:variant, carton_package_type: carton)
      carton.update!(length: 80)

      expect(variant.reload.carton_volume).to eq(BigDecimal('0.06'))
    end

    it 'is nil without a carton' do
      expect(build(:variant).carton_volume).to be_nil
    end
  end

  describe '#units_per_pallet' do
    it 'multiplies out the packing chain' do
      variant = build(:variant, units_per_carton: 24, cartons_per_pallet: 40)

      expect(variant.units_per_pallet).to eq(960)
    end

    it 'is nil when either half is missing' do
      expect(build(:variant, units_per_carton: 24).units_per_pallet).to be_nil
      expect(build(:variant, cartons_per_pallet: 40).units_per_pallet).to be_nil
    end
  end

  describe 'validations' do
    it 'refuses a non-positive carton weight or pallet count' do
      expect(build(:variant, carton_weight: 0)).not_to be_valid
      expect(build(:variant, cartons_per_pallet: 0)).not_to be_valid
    end
  end

  describe '#dimensions_unit' do
    it 'keeps the variant own unit when set' do
      expect(build(:variant, dimensions_unit: 'mm').dimensions_unit).to eq('mm')
    end

    it 'follows the store unit system when unset' do
      stub_store_preferences(store, unit_system: 'metric')

      expect(create(:variant).dimensions_unit).to eq('cm')
    end
  end
end
