require 'spec_helper'

describe Spree::StoreCreditType do
  it 'warns that the class is a deprecated shell' do
    expect(Spree::Deprecation).to receive(:warn).with(/Spree::StoreCreditType is deprecated/)

    described_class.new(name: 'Expiring')
  end
end
