require 'spec_helper'

describe Spree::ProductType, type: :model do
  it_behaves_like 'metadata'

  describe 'fulfillment_types' do
    it 'defaults to shipping' do
      expect(described_class.new.fulfillment_types).to eq(['shipping'])
    end

    it 'persists an explicit value' do
      product_type = create(:product_type, fulfillment_types: %w[shipping pickup])

      expect(product_type.reload.fulfillment_types).to eq(%w[shipping pickup])
    end

    it 'rejects types outside the Spree.fulfillment_types registry' do
      product_type = build(:product_type, fulfillment_types: %w[shipping freigt])

      expect(product_type).not_to be_valid
      expect(product_type.errors[:fulfillment_types].first).to include('freigt')
    end

    it 'accepts a custom type once registered' do
      Spree.fulfillment_types << 'freight'

      expect(build(:product_type, fulfillment_types: ['freight'])).to be_valid
    ensure
      Spree.fulfillment_types.delete('freight')
    end

    it 'leaves persisted rows with unregistered types savable when untouched' do
      product_type = create(:product_type)
      product_type.update_column(:fulfillment_types, ['legacy_freight'])

      product_type.reload.name = 'Renamed'
      expect(product_type.save).to be true
    end
  end

  describe '#digital?' do
    it 'is true only when digital is the sole fulfillment type' do
      expect(build(:product_type, fulfillment_types: ['digital'])).to be_digital
      expect(build(:product_type, fulfillment_types: %w[digital shipping])).not_to be_digital
      expect(build(:product_type)).not_to be_digital
    end
  end

  describe '#requires_shipping?' do
    it 'is true when shipping is among the fulfillment types' do
      expect(build(:product_type)).to be_requires_shipping
      expect(build(:product_type, fulfillment_types: ['digital'])).not_to be_requires_shipping
    end
  end

  describe 'deletion' do
    let(:product_type) { create(:product_type) }

    it 'is restricted while products use the type' do
      create(:product, product_type: product_type)

      expect(product_type.destroy).to be(false)
      expect(product_type.errors[:base]).to be_present
      expect(product_type.reload).to be_persisted
    end

    it 'destroys its joins when unused' do
      product_type.option_types << create(:option_type)

      expect { product_type.destroy }.to change(Spree::OptionTypeProductType, :count).by(-1)
    end
  end
  describe '#custom_field_definitions=' do
    let(:product_type) { create(:product_type) }
    let(:existing) { create(:custom_field_definition, key: 'wattage') }
    let(:incoming) { create(:custom_field_definition, key: 'voltage') }

    before do
      create(:product_type_custom_field_definition, product_type: product_type,
                                                    custom_field_definition: existing)
    end

    it 'replaces the set' do
      product_type.update!(custom_field_definitions: [{ id: incoming.prefixed_id, required: true }])

      expect(product_type.reload.custom_field_definitions).to eq([incoming])
    end

    # The removal and the writes are one unit — a rejected payload must not
    # leave the type with neither its old joins nor its new ones.
    it 'keeps the existing joins when the payload names an unknown definition' do
      product_type.update(custom_field_definitions: [{ id: 'cfdef_nonexistent', required: true }])

      expect(product_type.reload.custom_field_definitions).to eq([existing])
      expect(product_type.errors[:custom_field_definitions]).to be_present
    end

    it 'keeps the existing joins when a definition is not for products' do
      order_definition = create(:custom_field_definition, :for_order)

      product_type.update(custom_field_definitions: [{ id: order_definition.prefixed_id }])

      expect(product_type.reload.custom_field_definitions).to eq([existing])
    end
  end
end
