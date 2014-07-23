# encoding: utf-8

require 'spec_helper'

describe Spree::Order do
  describe "#multi_consignment?" do
    it "should be false when there is only one consignment" do
      @order = Spree::Order.create
      @order.consignments.create!
      @order.should_not be_multi_consignment
    end

    it "should be true otherwise" do
      @order = Spree::Order.create
      @order.consignments.create!
      @order.consignments.create!
      @order.should be_multi_consignment
    end
  end
end
