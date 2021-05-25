require 'spec_helper'

describe Spree::Property, type: :model do
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
    let(:product) { create(:product) }
    let(:product_2) { create(:product) }

    let(:product_property) { create(:product_property, property: property, product: product) }
    let(:product_property_2) { create(:product_property, property: property, product: product_2, value: 'Test Test') }

    before { product_property.update_column(:value, 'some value') }

    context 'filterable property' do
      it { expect { property.update(filterable: true) }.to change { product_property.reload.filter_param }.from(nil) }
      it { expect { property.update(filterable: true) }.not_to change { product_property_2.reload.updated_at } }
    end

    context 'not-filterable property' do
      it { expect { property.update(name: 'test') }.not_to change { product_property.reload.filter_param }.from(nil) }
    end
  end
end
