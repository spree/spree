require 'spec_helper'
require 'email_spec'

describe Spree::ShipmentMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:shipment) do
    order = stub_model(Spree::Order)
    product = stub_model(Spree::Product, :name => %Q{The "BEST" product})
    variant = stub_model(Spree::Variant, :product => product)
    line_item = stub_model(Spree::LineItem, :variant => variant, :order => order, :quantity => 1, :price => 5)
    shipment = stub_model(Spree::Shipment)
    shipment.stub(:line_items => [line_item], :order => order)
    shipment.stub(:tracking_url => "TRACK_ME")
    shipment
  end

  context ":from not set explicitly" do
    it "falls back to spree config" do
      message = Spree::ShipmentMailer.shipped_email(shipment)
      message.from.should == [Spree::Config[:mails_from]]
    end
  end

  # Regression test for #2196
  it "doesn't include out of stock in the email body" do
    shipment_email = Spree::ShipmentMailer.shipped_email(shipment)
    shipment_email.body.should_not include(%Q{Out of Stock})
  end

  it "shipment_email accepts an shipment id as an alternative to an Shipment object" do
    Spree::Shipment.should_receive(:find).with(shipment.id).and_return(shipment)
    lambda {
      shipped_email = Spree::ShipmentMailer.shipped_email(shipment.id)
    }.should_not raise_error
  end

  context "emails must be translatable" do
    context "shipped_email" do
      context "pt-BR locale" do
        before do
          pt_br_shipped_email = { :spree => { :shipment_mailer => { :shipped_email => { :dear_customer => 'Caro Cliente,' } } } }
          I18n.backend.store_translations :'pt-BR', pt_br_shipped_email
          I18n.locale = :'pt-BR'
        end

        after do
          I18n.locale = I18n.default_locale
        end

        specify do
          shipped_email = Spree::ShipmentMailer.shipped_email(shipment)
          shipped_email.body.should include("Caro Cliente,")
        end
      end
    end
  end
end
