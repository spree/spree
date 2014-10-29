require 'spec_helper'

describe Spree::Gateway, :type => :model do
  class Provider
    def initialize(options)
    end

    def imaginary_method

    end
  end

  class TestGateway < Spree::Gateway
    def provider_class
      Provider
    end
  end

  it "passes through all arguments on a method_missing call" do
    gateway = TestGateway.new
    expect(gateway.provider).to receive(:imaginary_method).with('foo')
    gateway.imaginary_method('foo')
  end

  context "fetching payment sources" do
    let(:order) { Spree::Order.create(user_id: 1) }

    let(:has_card) { create(:credit_card_payment_method) }
    let(:no_card) { create(:credit_card_payment_method) }

    let(:cc) do
      create(:credit_card, payment_method: has_card, gateway_customer_profile_id: "EFWE")
    end

    let(:payment) do
      create(:payment, order: order, source: cc, payment_method: has_card)
    end

    it "finds credit cards associated on a order completed" do
      allow(payment.order).to receive_messages completed?: true

      expect(no_card.reusable_sources(payment.order)).to be_empty
      expect(has_card.reusable_sources(payment.order)).not_to be_empty
    end

    it "finds credit cards associated with the order user" do
      cc.update_column :user_id, 1
      allow(payment.order).to receive_messages completed?: false

      expect(no_card.reusable_sources(payment.order)).to be_empty
      expect(has_card.reusable_sources(payment.order)).not_to be_empty
    end
  end
end
