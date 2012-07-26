require_relative '../../../app/models/spree/order_components/payment'
require 'fakes/order'

module Spree
  class FakePaymentsOrder < Spree::FakeOrder
    attr_accessor :payment_total, :total
    include Spree::OrderComponents::Payment
  end
end

describe Spree::OrderComponents::Payment do
  let(:order) { Spree::FakePaymentsOrder.new }

  context "#outstanding_balance" do
    it "should return positive amount when payment_total is less than total" do
      order.payment_total = 20.20
      order.total = 30.30
      order.outstanding_balance.should be_within(0.001).of(10.10)
    end

    it "should return negative amount when payment_total is greater than total" do
      order.total = 8.20
      order.payment_total = 10.20
      order.outstanding_balance.should be_within(0.001).of(-2.00)
    end

  end

  context "#outstanding_balance?" do
    it "should be true when total greater than payment_total" do
      order.total = 10.10
      order.payment_total = 9.50
      order.outstanding_balance?.should be_true
    end
    it "should be true when total less than payment_total" do
      order.total = 8.25
      order.payment_total = 10.44
      order.outstanding_balance?.should be_true
    end
    it "should be false when total equals payment_total" do
      order.total = 10.10
      order.payment_total = 10.10
      order.outstanding_balance?.should be_false
    end
  end

  context "#payment_method" do
    it "should return payment.payment_method if payment is present" do
      payment = stub(:payment)
      payment.stub :payment_method => stub(:payment_method)
      order.stub(:payments => [payment])
      order.payment_method.should == order.payments.first.payment_method
    end

    it "should return the first payment method from available_payment_methods if payment is not present" do
      payment_method = stub(:payment_method)
      order.should_receive(:available_payment_methods).and_return([payment_method])
      order.payment_method.should == payment_method
    end
  end

  context "#process_payments!" do
    it "should process the payments" do
      order.stub!(:payments).and_return([stub])
      order.payment.should_receive(:process!)
      order.process_payments!
    end
  end
end

