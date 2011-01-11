require File.dirname(__FILE__) + '/../spec_helper'

describe ShippingMethod do

  let(:order) { Order.new }

  it "should be available if the ship address falls within the method's zone"
  #TODO - write some tests about availability - waiting to see if we like the older implementation before we bother with the tests

end
