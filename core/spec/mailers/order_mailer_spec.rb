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

  context "emails must be translatable by locale" do
    context "en" do
      before do
        en = { :order_mailer => { :confirm_email => { :dear_customer => 'Dear Customer,' } } }
        I18n.backend.store_translations :en, en
        I18n.locale = :en
      end

      specify do
        confirmation_email = Spree::OrderMailer.confirm_email(order)
        confirmation_email.body.should include("Dear Customer,")
      end
    end

    context "pt-BR" do
      before do
        pt_br = { :order_mailer => { :confirm_email => { :dear_customer => 'Caro Cliente,' } } }
        I18n.backend.store_translations :'pt-BR', pt_br
        I18n.locale = :'pt-BR'
      end

      specify do
        confirmation_email = Spree::OrderMailer.confirm_email(order)
        confirmation_email.body.should include("Caro Cliente,")
      end
    end
  end
end
