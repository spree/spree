require 'spec_helper'

describe Spree::ProductType, type: :model do
  it_behaves_like 'metadata'

  describe 'delivery profile template' do
    it 'is optional — a type without one leaves products on the store default' do
      expect(build(:product_type).delivery_profile).to be_nil
    end

    it 'stamps its profile onto products at creation' do
      profile = create(:delivery_profile)
      product_type = create(:product_type, delivery_profile: profile)
      product = create(:product, store: profile.store, product_type: product_type)

      expect(product.delivery_profile).to eq(profile)
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

    # Definitions are store-owned, so another store's is unknown here rather
    # than a join that fails silently on save.
    it 'refuses a definition owned by another store' do
      foreign = create(:custom_field_definition, store: create(:store), resource_type: 'Spree::Product')

      product_type.update(custom_field_definitions: [{ id: foreign.prefixed_id, required: true }])

      expect(product_type.reload.custom_field_definitions).to eq([existing])
      expect(product_type.errors[:custom_field_definitions]).to be_present
    end

    it 'keeps the existing joins when a definition is not for products' do
      order_definition = create(:custom_field_definition, :for_order)

      product_type.update(custom_field_definitions: [{ id: order_definition.prefixed_id }])

      expect(product_type.reload.custom_field_definitions).to eq([existing])
      expect(product_type.errors[:custom_field_definitions]).to be_present
    end
  end
end
