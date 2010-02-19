require 'test_helper'

class CreditcardPaymentTest < ActiveSupport::TestCase
  fixtures :payment_methods

  context "validation" do
    setup do           
      @order = Factory(:order)
    end

    context "when amount is positive but exceeds outstanding balance" do
      setup do
        @payment = @order.payments.new(:amount => 3.00, :payment_method => Gateway.current)
        @payment.order.stub!(:outstanding_balance, :return => 2.00)
      end
      should "be invalid with error on amount" do
        assert !@payment.valid?
        assert @payment.errors.on(:amount)
      end
    end

    context "when amount is negative payment but exceeds credit owed" do
      setup do
        @payment = @order.payments.new(:amount => -5.00, :payment_method => Gateway.current)
        @payment.order.stub!(:outstanding_credit, :return => 2.50)
      end
      should "be invalid with error on amount" do
        assert !@payment.valid?
        assert @payment.errors.on(:amount)
      end
    end

    context "when amount is positive and equal to outstanding balance" do
      setup do
        @payment = @order.payments.new(:amount => 5.00, :payment_method => Gateway.current)
        @payment.order.stub!(:outstanding_balance, :return => 5.00)
      end
      should "be valid" do
        assert @payment.valid?
      end
    end

    context "when amount is negative and equal to credit owed" do
      setup do
        @payment = @order.payments.new(:amount => -5.00, :payment_method => Gateway.current)
        @payment.order.stub!(:outstanding_credit, :return => 5.00)
      end
      should "be valid" do
        assert @payment.valid?
      end
    end

  end
end
