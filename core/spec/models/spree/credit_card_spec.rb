require 'spec_helper'

describe Spree::CreditCard do

  let(:valid_credit_card_attributes) { { number: '4111111111111111', verification_value: '123', month: 12, year: 2014 } }

  def self.payment_states
    Spree::Payment.state_machine.states.keys
  end

  def stub_rails_env(environment)
    Rails.stub(env: ActiveSupport::StringInquirer.new(environment))
  end

  let(:credit_card) { Spree::CreditCard.new }

  before(:each) do

    @order = create(:order)
    @payment = Spree::Payment.create({ amount: 100, order: @order }, without_protection: true)

    @success_response = double('gateway_response', success?: true, authorization: '123', avs_result: { 'code' => 'avs-code' })
    @fail_response = double('gateway_response', success?: false)

    @payment_gateway = mock_model(Spree::PaymentMethod,
      payment_profiles_supported?: true,
      authorize: @success_response,
      purchase: @success_response,
      capture: @success_response,
      void: @success_response,
      credit: @success_response,
      environment: 'test'
    )

    @payment.stub payment_method: @payment_gateway
  end

  context "#can_capture?" do
    it "should be true if payment is pending" do
      payment = mock_model(Spree::Payment, pending?: true, created_at: Time.now)
      credit_card.can_capture?(payment).should be_true
    end

    it "should be true if payment is checkout" do
      payment = mock_model(Spree::Payment, pending?: false, checkout?: true, created_at: Time.now)
      credit_card.can_capture?(payment).should be_true
    end
  end

  context "#can_void?" do
    it "should be true if payment is not void" do
      payment = mock_model(Spree::Payment, void?: false)
      credit_card.can_void?(payment).should be_true
    end
  end

  context "#can_credit?" do
    it "should be false if payment is not completed" do
      payment = mock_model(Spree::Payment, completed?: false)
      credit_card.can_credit?(payment).should be_false
    end

    it "should be false when order payment_state is not 'credit_owed'" do
      payment = mock_model(Spree::Payment, completed?: true, order: mock_model(Spree::Order, payment_state: 'paid'))
      credit_card.can_credit?(payment).should be_false
    end

    it "should be false when credit_allowed is zero" do
      payment = mock_model(Spree::Payment, completed?: true, credit_allowed: 0, order: mock_model(Spree::Order, payment_state: 'credit_owed'))
      credit_card.can_credit?(payment).should be_false
    end
  end

  context "#valid?" do
    it "should validate presence of number" do
      credit_card.attributes = valid_credit_card_attributes.except(:number)
      credit_card.should_not be_valid
      credit_card.errors[:number].should == ["can't be blank"]
    end

    it "should validate presence of security code" do
      credit_card.attributes = valid_credit_card_attributes.except(:verification_value)
      credit_card.should_not be_valid
      credit_card.errors[:verification_value].should == ["can't be blank"]
    end

    it "should validate expiration is not in the past" do
      credit_card.month = 1.month.ago.month
      credit_card.year = 1.month.ago.year
      credit_card.should_not be_valid
      credit_card.errors[:base].should == ["Card has expired"]
    end

    it "does not run expiration in the past validation if month is not set" do
      credit_card.month = nil
      credit_card.year = Time.now.year
      credit_card.should_not be_valid
      credit_card.errors[:card].should be_blank
    end

    it "does not run expiration in the past validation if year is not set" do
      credit_card.month = Time.now.month
      credit_card.year = nil
      credit_card.should_not be_valid
      credit_card.errors[:card].should be_blank
    end
    
    it "does not run expiration in the past validation if year and month are empty" do
      credit_card.year = ""
      credit_card.month = ""
      credit_card.should_not be_valid
      credit_card.errors[:card].should be_blank
    end 

    it "should only validate on create" do
      credit_card.attributes = valid_credit_card_attributes
      credit_card.save
      credit_card.should be_valid
    end
  end

  context "#save" do
    before do
      credit_card.attributes = valid_credit_card_attributes
      credit_card.save!
    end

    let!(:persisted_card) { Spree::CreditCard.find(credit_card.id) }

    it "should not actually store the number" do
      persisted_card.number.should be_blank
    end

    it "should not actually store the security code" do
      persisted_card.verification_value.should be_blank
    end
  end

  context "#spree_cc_type" do
    before { credit_card.attributes = valid_credit_card_attributes }

    context "in development mode" do
      before do
        stub_rails_env("production")
      end

      it "should return visa" do
        credit_card.save
        credit_card.spree_cc_type.should == 'visa'
      end
    end

    context "in production mode" do
      before { stub_rails_env("production") }

      it "should return the actual cc_type for a valid number" do
        credit_card.number = '378282246310005'
        credit_card.save
        credit_card.spree_cc_type.should == 'american_express'
      end
    end
  end

  context "#set_card_type" do
    before :each do
      stub_rails_env("production")
      credit_card.attributes = valid_credit_card_attributes
    end

    it "stores the credit card type after validation" do
      credit_card.number = '6011000990139424'
      credit_card.save
      credit_card.spree_cc_type.should == 'discover'
    end

    it "does not overwrite the credit card type when loaded and saved" do
      credit_card.number = '5105105105105100'
      credit_card.save
      credit_card.number = 'XXXXXXXXXXXX5100'
      credit_card.save
      credit_card.spree_cc_type.should == 'master'
    end
  end

  context "#associations" do
    it "should be able to access its payments" do
      expect { credit_card.payments.all }.not_to raise_error
    end
  end
  
  context "#to_active_merchant" do
    before do
      credit_card.number = "4111111111111111"
      credit_card.year = Time.now.year
      credit_card.month = Time.now.month
      credit_card.first_name = "Bob"
      credit_card.last_name = "Boblaw"
      credit_card.verification_value = 123
    end

    it "converts to an ActiveMerchant::Billing::CreditCard object" do
      am_card = credit_card.to_active_merchant
      am_card.number.should == "4111111111111111"
      am_card.year.should == Time.now.year
      am_card.month.should == Time.now.month
      am_card.first_name.should == "Bob"
      am_card.last_name = "Boblaw"
      am_card.verification_value.should == 123
    end
  end
end
