require 'spec_helper'

describe Spree::Creditcard do

  context 'validation' do
    it { should have_valid_factory(:creditcard) }
  end

  let(:valid_creditcard_attributes) { {:number => '4111111111111111', :verification_value => '123', :month => 12, :year => 2014} }

  def stub_rails_env(environment)
    Rails.stub(:env => ActiveSupport::StringInquirer.new(environment))
  end

  let(:creditcard) { Spree::Creditcard.new }

  before(:each) do

    @order = create(:order)
    @payment = Spree::Payment.create({:amount => 100, :order => @order}, :without_protection => true)

    @success_response = mock('gateway_response', :success? => true, :authorization => '123', :avs_result => {'code' => 'avs-code'})
    @fail_response = mock('gateway_response', :success? => false)

    @payment_gateway = mock_model(Spree::PaymentMethod,
      :payment_profiles_supported? => true,
      :authorize => @success_response,
      :purchase => @success_response,
      :capture => @success_response,
      :void => @success_response,
      :credit => @success_response,
      :environment => 'test'
    )

    @payment.stub :payment_method => @payment_gateway
  end

  context "#can_capture?" do
    it "should be true if payment state is pending" do
      payment = mock_model(Spree::Payment, :state => 'pending', :created_at => Time.now)
      creditcard.can_capture?(payment).should be_true
    end
  end

  context "when transaction is more than 12 hours old" do
    let(:payment) { mock_model(Spree::Payment, :state => "completed",
                                               :created_at => Time.now - 14.hours,
                                               :amount => 99.00,
                                               :credit_allowed => 100.00,
                                               :order => mock_model(Spree::Order, :payment_state => 'credit_owed')) }

    context "#can_credit?" do

      it "should be true when payment state is 'completed' and order payment_state is 'credit_owed' and credit_allowed is greater than amount" do
        creditcard.can_credit?(payment).should be_true
      end

      it "should be false when order payment_state is not 'credit_owed'" do
        payment.order.stub(:payment_state => 'paid')
        creditcard.can_credit?(payment).should be_false
      end

      it "should be false when credit_allowed is zero" do
        payment.stub(:credit_allowed => 0)
        creditcard.can_credit?(payment).should be_false
      end

      (PAYMENT_STATES - ['completed']).each do |state|
        it "should be false if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_credit?(payment).should be_false
        end
      end

    end

    context "#can_void?" do
      (PAYMENT_STATES - ['void']).each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          payment.stub :void? => false
          creditcard.can_void?(payment).should be_true
        end
      end

      it "should be valse if payment state is void" do
        payment.stub :state => 'void'
        creditcard.can_void?(payment).should be_false
      end
    end
  end

  context "when transaction is less than 12 hours old" do
    let(:payment) { mock_model(Spree::Payment, :state => 'completed') }

    context "#can_void?" do
      (PAYMENT_STATES - ['void']).each do |state|
        it "should be true if payment state is #{state}" do
          payment.stub :state => state
          creditcard.can_void?(payment).should be_true
        end
      end

      it "should be false if payment state is void" do
        payment.stub :state => 'void'
        creditcard.can_void?(payment).should be_false
      end

    end
  end

  context "#valid?" do
    it "should validate presence of number" do
      creditcard.attributes = valid_creditcard_attributes.except(:number)
      creditcard.should_not be_valid
      creditcard.errors[:number].should == ["can't be blank"]
    end

    it "should validate presence of security code" do
      creditcard.attributes = valid_creditcard_attributes.except(:verification_value)
      creditcard.should_not be_valid
      creditcard.errors[:verification_value].should == ["can't be blank"]
    end

    it "should only validate on create" do
      creditcard.attributes = valid_creditcard_attributes
      creditcard.save
      creditcard.should be_valid
    end
  end

  context "#save" do
    before do
      creditcard.attributes = valid_creditcard_attributes
      creditcard.save!
    end

    let!(:persisted_card) { Spree::Creditcard.find(creditcard.id) }

    it "should not actually store the number" do
      persisted_card.number.should be_blank
    end

    it "should not actually store the security code" do
      persisted_card.verification_value.should be_blank
    end
  end

  context "#spree_cc_type" do
    before do
      creditcard.attributes = valid_creditcard_attributes
    end

    context "in development mode" do
      before do
        stub_rails_env("production")
      end

      it "should return visa" do
        creditcard.save
        creditcard.spree_cc_type.should == "visa"
      end
    end

    context "in production mode" do
      before do
        stub_rails_env("production")
      end

      it "should return the actual cc_type for a valid number" do
        creditcard.number = "378282246310005"
        creditcard.save
        creditcard.spree_cc_type.should == "american_express"
      end
    end
  end

  context "#set_card_type" do
    before :each do
      stub_rails_env("production")
      creditcard.attributes = valid_creditcard_attributes
    end

    it "stores the creditcard type after validation" do
      creditcard.number = "6011000990139424"
      creditcard.save
      creditcard.spree_cc_type.should == "discover"
    end

    it "does not overwrite the creditcard type when loaded and saved" do
      creditcard.number = "5105105105105100"
      creditcard.save
      creditcard.number = "XXXXXXXXXXXX5100"
      creditcard.save
      creditcard.spree_cc_type.should == "master"
    end
  end
end

