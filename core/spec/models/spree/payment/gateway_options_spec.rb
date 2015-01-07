require "spec_helper"

RSpec.describe Spree::Payment::GatewayOptions, type: :model do
  let(:options) { Spree::Payment::GatewayOptions.new(payment) }

  let(:payment) do
    double(
      Spree::Payment,
      order: order,
      number: "P1566",
      currency: "EUR"
    )
  end

  let(:order) do
    double(
      Spree::Order,
      email: "test@email.com",
      user_id: 144,
      last_ip_address: "0.0.0.0",
      number: "R1444",
      ship_total: "12.44".to_d,
      additional_tax_total: "1.53".to_d,
      item_total: "15.11".to_d,
      promo_total: "2.57".to_d,
      bill_address: bill_address,
      ship_address: ship_address
    )
  end

  let(:bill_address) do
    double Spree::Address, active_merchant_hash: { bill: :address }
  end
  let(:ship_address) do
    double Spree::Address, active_merchant_hash: { ship: :address }
  end

  describe "#email" do
    subject { options.email }
    it { should == "test@email.com" }
  end

  describe "#customer" do
    subject { options.customer }
    it { should == "test@email.com" }
  end

  describe "#customer_id" do
    subject { options.customer_id }
    it { should == 144 }
  end

  describe "#ip" do
    subject { options.ip }
    it { should == "0.0.0.0" }
  end

  describe "#order_id" do
    subject { options.order_id }
    it { should == "R1444-P1566" }
  end

  describe "#shipping" do
    subject { options.shipping }
    it { should == 1244 }
  end

  describe "#tax" do
    subject { options.tax }
    it { should == 153 }
  end

  describe "#subtotal" do
    subject { options.subtotal }
    it { should == 1511 }
  end

  describe "#discount" do
    subject { options.discount }
    it { should == 257 }
  end

  describe "#currency" do
    subject { options.currency }
    it { should == "EUR" }
  end

  describe "#billing_address" do
    subject { options.billing_address }
    it { should == { bill: :address } }
  end

  describe "#shipping_address" do
    subject { options.shipping_address }
    it { should == { ship: :address } }
  end

  describe "#to_hash" do
    subject { options.to_hash }
    let(:expected) do
      {
        email: "test@email.com",
        customer: "test@email.com",
        customer_id: 144,
        ip: "0.0.0.0",
        order_id: "R1444-P1566",
        shipping: "1244".to_d,
        tax: "153".to_d,
        subtotal: "1511".to_d,
        discount: "257".to_d,
        currency: "EUR",
        billing_address: { bill: :address },
        shipping_address: { ship: :address }
      }
    end
    it { should == expected }
  end

end
