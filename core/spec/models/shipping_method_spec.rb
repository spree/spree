require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingMethod do

  context 'validations' do
    it { should have_valid_factory(:shipping_method) }
  end

end
