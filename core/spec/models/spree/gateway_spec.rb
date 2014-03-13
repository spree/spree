require 'spec_helper'

describe Spree::Gateway do
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
    gateway.provider.should_receive(:imaginary_method).with('foo')
    gateway.imaginary_method('foo')
  end

  it "finds credit cards associated on a given order" do
    has_card = create(:credit_card_payment_method)
    no_card = create(:credit_card_payment_method)
    payment = create(:payment, source: create(:credit_card), payment_method: has_card)

    expect(no_card.sources_by_order(payment.order)).to be_empty
    expect(has_card.sources_by_order(payment.order)).not_to be_empty
  end
end
