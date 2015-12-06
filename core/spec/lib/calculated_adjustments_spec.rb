require 'spec_helper'

describe Spree::CalculatedAdjustments do
  it 'should add has_one :calculator relationship' do
    expect(
      Spree::ShippingMethod
        .reflect_on_all_associations(:has_one)
        .map(&:name)
    ).to include(:calculator)
  end
end
