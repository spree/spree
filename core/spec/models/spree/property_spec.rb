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
      let(:product_property_1) { create(:product_property, property: property, value: 'Some 10% Value') }
      let(:product_property_2) { create(:product_property, property: property, value: 'Some 10% Value') }
      let(:product_property_3) { create(:product_property, property: property, value: 'Another 20% Value') }

      let(:scope) { [product_property_1, product_property_2, product_property_3] }

      it do
        expect(property.uniq_values(product_properties_scope: scope)).to eq(
          [
            ['some-10-value', 'Some 10% Value'],
            ['another-20-value', 'Another 20% Value']
          ]
        )
      end
    end
  end
end
