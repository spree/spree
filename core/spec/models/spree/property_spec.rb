require 'spec_helper'

describe Spree::Property, type: :model do
  let(:store) { @default_store }

  it_behaves_like 'metadata'

  describe 'translations' do
    let!(:property) { create(:property, name: 'brand', presentation: 'Brand') }

    before do
      Mobility.with_locale(:pl) do
        property.update!(presentation: 'Marka')
      end
    end

    let(:property_pl_translation) { property.translations.find_by(locale: 'pl') }

    it 'translates property fields' do
      expect(property.presentation).to eq('Brand')

      expect(property_pl_translation).to be_present
      expect(property_pl_translation.presentation).to eq('Marka')
    end
  end

  describe 'scopes' do
    let!(:properties) { create_list(:property, 2, display_on: 'both') }
    let!(:frontend_properties) { create_list(:property, 2, display_on: 'front_end') }
    let!(:backend_properties) { create_list(:property, 2, display_on: 'back_end') }

    describe '.available' do
      subject { described_class.available }

      it { is_expected.to match_array(properties) }
    end

    describe '.available_on_front_end' do
      subject { described_class.available_on_front_end }

      it { is_expected.to match_array(properties + frontend_properties) }
    end

    describe '.available_on_back_end' do
      subject { described_class.available_on_back_end }

      it { is_expected.to match_array(properties + backend_properties) }
    end
  end

  describe 'callbacks' do
    describe '#normalize_name' do
      let!(:option_type) { build(:option_type, name: 'Shirt Size') }

      it 'should parameterize the name' do
        option_type.name = 'Shirt Size'
        option_type.save!
        expect(option_type.name).to eq('shirt-size')
      end
    end
  end

  context 'setting filter param' do
    subject { build(:property, name: 'Brand Name') }

    it { expect { subject.save! }.to change(subject, :filter_param).from(nil).to('brand-name') }
  end

  describe '#uniq_values' do
    let(:property) { create(:property) }

    before do
      create(:product_property, property: property, value: 'Some Value')
      create(:product_property, property: property, value: 'Some Value')
      create(:product_property, property: property, value: 'Another 10% Value')
    end

    it { expect(property.uniq_values).to eq([['some-value', 'Some Value'], ['another-10-value', 'Another 10% Value']]) }

    context 'when narrowing the scope of product properties' do
      let!(:product_property_1) { create(:product_property, property: property, value: 'Some 10% Value') }
      let!(:product_property_2) { create(:product_property, property: property, value: 'Some 10% Value') }
      let!(:product_property_3) { create(:product_property, property: property, value: 'Another 20% Value') }

      let(:scope) { [product_property_1, product_property_2, product_property_3] }

      let(:scope_uniq_values) do
        [
          ['some-10-value', 'Some 10% Value'],
          ['another-20-value', 'Another 20% Value']
        ]
      end

      it { expect(property.uniq_values(product_properties_scope: scope)).to eq(scope_uniq_values) }
    end

    context 'when caching' do
      it 'correctly returns uniq values' do
        expect(property.uniq_values).to eq([['some-value', 'Some Value'], ['another-10-value', 'Another 10% Value']])

        product_property_1 = create(:product_property, property: property, value: 'Some 20% Value')
        expect(property.uniq_values).to eq(
          [
            ['some-value', 'Some Value'],
            ['another-10-value', 'Another 10% Value'],
            ['some-20-value', 'Some 20% Value']
          ]
        )

        product_property_2 = create(:product_property, property: property, value: 'Another 20% Value')
        product_property_3 = create(:product_property, property: property, value: 'Another 30% Value')

        scope = [product_property_1, product_property_2]
        other_scope = [product_property_2, product_property_3]

        expect(property.uniq_values(product_properties_scope: scope)).to eq(
          [
            ['some-20-value', 'Some 20% Value'],
            ['another-20-value', 'Another 20% Value']
          ]
        )

        expect(property.uniq_values(product_properties_scope: other_scope)).to eq(
          [
            ['another-20-value', 'Another 20% Value'],
            ['another-30-value', 'Another 30% Value']
          ]
        )
      end
    end
  end

  describe '#ensure_product_properties_have_filter_params' do
    let(:property) { create(:property) }
    let(:product) { create(:product, stores: [store]) }
    let(:product_2) { create(:product, stores: [store]) }

    let(:product_property) { create(:product_property, property: property, product: product) }
    let(:product_property_2) { create(:product_property, property: property, product: product_2, value: 'Test Test') }

    before do
      product_property.update_column(:filter_param, nil)
      product_property.update_column(:value, 'some_value')
    end

    context 'filterable property' do
      it { expect { property.update(filterable: true) }.to change { product_property.reload.filter_param }.from(nil) }
      it { expect { property.update(filterable: true) }.not_to change { product_property_2.reload.updated_at } }
    end

    context 'not-filterable property' do
      it { expect { property.update(name: 'test') }.not_to change { product_property.reload.filter_param }.from(nil) }
    end
  end

  describe '#after_touch callback' do
    let!(:product_property) { create(:product_property) }

    it 'touches the product' do
      expect { product_property.property.touch }.to change { product_property.product.reload.updated_at }
    end
  end

  describe '#after_update callback' do
    let!(:product_property) { create(:product_property) }

    context 'with DEPENDENCY_UPDATE_FIELDS' do
      it 'touches the product' do
        expect { product_property.property.update(name: 'test') }.to change { product_property.product.reload.updated_at }
      end
    end

    context 'without DEPENDENCY_UPDATE_FIELDS' do
      it 'does not touch the product' do
        expect { product_property.property.update(updated_at: Time.now) }.not_to change { product_property.product.reload.updated_at }
      end
    end
  end

  describe '#kind_to_metafield_type' do
    let(:property) { create(:property, kind: 'short_text') }

    it 'returns the correct metafield type' do
      expect(property.kind_to_metafield_type).to eq('Spree::Metafields::ShortText')
    end

    context 'when the property kind is long_text' do
      let(:property) { create(:property, kind: 'long_text') }

      it 'returns the correct metafield type' do
        expect(property.kind_to_metafield_type).to eq('Spree::Metafields::LongText')
      end
    end

    context 'when the property kind is number' do
      let(:property) { create(:property, kind: 'number') }

      it 'returns the correct metafield type' do
        expect(property.kind_to_metafield_type).to eq('Spree::Metafields::Number')
      end
    end

    context 'when the property kind is rich_text' do
      let(:property) { create(:property, kind: 'rich_text') }

      it 'returns the correct metafield type' do
        expect(property.kind_to_metafield_type).to eq('Spree::Metafields::RichText')
      end
    end
  end
end
