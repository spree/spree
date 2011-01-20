require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingMethod do

  context 'factory' do
    let(:shipping_method) { Factory(:shipping_method) }
    specify { shipping_method.new_record?.should be_false }
  end

end
