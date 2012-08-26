require 'spec_helper'
require 'email_spec'

describe Spree::OrderMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:order) do
    order = stub_model(Spree::Order)
    product = stub_model(Spree::Product, :name => %Q{The "BEST" product})
    variant = stub_model(Spree::Variant, :product => product)
    line_item = stub_model(Spree::LineItem, :variant => variant, :order => order, :quantity => 1, :price => 5)
    order.stub(:line_items => [line_item])
    order
  end

  it "doesn't aggressively escape double quotes in confirmation body" do
    confirmation_email = Spree::OrderMailer.confirm_email(order)
    confirmation_email.body.should_not include("&quot;")
  end

  context "only shows eligible adjustments in emails" do
    before do
      order.adjustments.create({:label    => "Eligible Adjustment",
                                :amount   => 10,
                                :eligible => true}, :without_protection => true)

      order.adjustments.create!({:label    => "Ineligible Adjustment",
                                 :amount   => -10,
                                 :eligible => false}, :without_protection => true)
    end

    let!(:confirmation_email) { Spree::OrderMailer.confirm_email(order) }
    let!(:cancel_email) { Spree::OrderMailer.cancel_email(order) }

    specify do
      confirmation_email.body.should_not include("Ineligible Adjustment")
    end

    specify do
      cancel_email.body.should_not include("Ineligible Adjustment")
    end
  end

end
