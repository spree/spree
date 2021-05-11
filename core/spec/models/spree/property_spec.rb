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
  end
end
