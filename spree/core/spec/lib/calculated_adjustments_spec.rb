require 'spec_helper'

describe Spree::CalculatedAdjustments do
  it 'adds has_one :calculator relationship' do
    assert Spree::ShippingMethod.reflect_on_all_associations(:has_one).map(&:name).include?(:calculator)
  end
end
