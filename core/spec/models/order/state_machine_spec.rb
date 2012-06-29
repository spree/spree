require 'spec_helper'

describe Spree::Order do
  let(:order) { stub_model(Spree::Order) }
  def disable(*steps)
    steps.each do |step|
      order.stub("#{step}_required?" => false)
    end
  end

  def enable(*steps)
    steps.each do |step|
      order.stub("#{step}_required?" => true)
    end
  end

  def should_transition_to(step)
    order.next!
    order.state.should == step.to_s
  end

  context "state transitions" do
    before do
      order.stub(:email_required? => false)
    end

    context "from cart" do
      before do
        order.state = 'cart'
      end

      it 'transitions to address' do
        should_transition_to(:address)
      end

      it "transitions to delivery if address not required" do
        disable(:address)
        should_transition_to(:delivery)
      end

      it "transitions to payment if address and delivery not required, but payment is" do
        disable(:address, :delivery)
        enable(:payment)
        should_transition_to(:payment)
      end

      it "transitions to confirm if address, delivery and payment not required, but confirmation is" do
        disable(:address, :delivery, :payment)
        enable(:confirmation)
        should_transition_to(:confirm)
      end

      it "transitions to complete if address, delivery, payment and confirmation not required" do
        disable(:address, :delivery, :payment, :confirmation)
        should_transition_to(:complete)
      end
    end

    context "from address" do
      before do
        order.state = 'address'
      end

      it "transitions to delivery" do
        should_transition_to(:delivery)
      end

      it "transitions to payment if delivery not required" do
        disable(:delivery)
        enable(:payment)
        should_transition_to(:payment)
      end

      it "transitions to confirm if delivery and payment not required, but confirmation is" do
        disable(:delivery, :payment)
        enable(:confirmation)
        should_transition_to(:confirm)
      end

      it "transitions to complete if delivery, payment and confirm are not required" do
        disable(:delivery, :payment, :confirmation)
        should_transition_to(:complete)
      end
    end

    context "from delivery" do
      before do
        order.state = 'delivery'
        order.stub(:has_available_payment)
        order.stub(:has_available_shipment)
        order.stub(:create_shipment!)
      end

      it "transitions to payment" do
        enable(:payment)
        should_transition_to(:payment)
      end

      it "transitions to confirm if payment not required, but confirmation is" do
        disable(:payment)
        enable(:confirmation)
        should_transition_to(:confirm)
      end

      it "transitions to complete if payment and confirmation not required" do
        disable(:payment, :confirmation)
        should_transition_to(:complete)
      end
    end

    context "from payment" do
      before do
        order.state = 'payment'
      end

      it "transitions to confirmation if confirmation is required" do
        enable(:confirmation)
        should_transition_to(:confirm)
      end

      it "transitions to ocmplete if confirmation is not required" do
        disable(:confirmation)
        should_transition_to(:complete)
      end
    end

    context "from confirm" do
      before do
        order.state = 'confirm'
      end

      it "transitions to complete" do
        should_transition_to(:complete)
      end
    end
  end

  context "steps" do
    before do
      enable(:address, :delivery, :payment, :confirmation, :complete)
    end

    it "requires address, delivery, payment, confirm and complete" do
      order.steps.should == %w(address delivery payment confirm complete)
    end

    it "does not require an address" do
      disable(:address)
      order.steps.should == %w(delivery payment confirm complete)
    end

    it "does not require a delivery" do
      disable(:delivery)
      order.steps.should == %w(address payment confirm complete)
    end

    it "does not require a payment" do
      disable(:payment)
      order.steps.should == %w(address delivery confirm complete)
    end

    it "does not require confirmation" do
      disable(:confirmation)
      order.steps.should == %w(address delivery payment complete)
    end
  end
end
