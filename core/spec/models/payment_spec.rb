require 'spec_helper'

describe Spree::Payment do

  context 'validation' do
    it { should have_valid_factory(:payment) }
  end

  let(:order) { mock_model(Spree::Order, :update! => nil, :payments => []) }
  let(:gateway) { Spree::Gateway::Bogus.new({:environment => 'test', :active => true}, :without_protection => true) }
  let(:card) { Factory(:creditcard) }

  before(:each) do
    @payment = Spree::Payment.new({:order => order}, :without_protection => true)
    @payment.payment_method = stub_model(Spree::PaymentMethod)
    @payment.payment_method.stub(:source_required? => true)
    @payment.source = mock_model(Spree::Creditcard, :save => true, :payment_gateway => nil, :process => nil, :credit => nil, :changed_for_autosave? => false)
    @payment.stub!(:valid?).and_return(true)
    @payment.stub!(:check_payments).and_return(nil)

    order.payments.stub!(:reload).and_return([@payment])
  end

  context "#process!" do

    context "when state is checkout" do
      before(:each) do
        @payment.source.stub!(:process!).and_return(nil)
      end
      it "should process the source" do
        @payment.source.should_receive(:process!)
        @payment.process!
      end
      it "should make the state 'processing'" do
        @payment.process!
        @payment.should be_processing
      end
    end

    context "when already processing" do
      before(:each) { @payment.state = 'processing' }
      it "should return nil without trying to process the source" do
        @payment.source.should_not_receive(:process!)
        @payment.process!.should == nil
      end
    end


    context "with source required" do
      context "raises an error if no source is specified" do
        before do
          @payment.source = nil
        end

        specify do
          lambda { @payment.process! }.should raise_error(Spree::Core::GatewayError, I18n.t(:payment_processing_failed))
        end
      end
    end

    context "with source optional" do
      context "raises no error if source is not specified" do
        before do
          @payment.source = nil
          @payment.payment_method.stub(:source_required? => false)
        end

        specify do
          lambda { @payment.process! }.should_not raise_error(Spree::Core::GatewayError)
        end
      end
    end

  end

  context "#credit_allowed" do
    it "is the difference between offsets total and payment amount" do
      @payment.amount = 100
      @payment.stub(:offsets_total).and_return(0)
      @payment.credit_allowed.should == 100
      @payment.stub(:offsets_total).and_return(80)
      @payment.credit_allowed.should == 20
    end
  end

  context "#can_credit?" do
    it "is true if credit_allowed > 0" do
      @payment.stub(:credit_allowed).and_return(100)
      @payment.can_credit?.should be_true
    end
    it "is false if credit_allowed is 0" do
      @payment.stub(:credit_allowed).and_return(0)
      @payment.can_credit?.should be_false
    end
  end

  context "#credit" do
    context "when amount <= credit_allowed" do
      it "makes the state processing" do
        @payment.state = 'completed'
        @payment.stub(:credit_allowed).and_return(10)
        @payment.credit(10)
        @payment.should be_processing
      end
      it "calls credit on the source with the payment and amount" do
        @payment.state = 'completed'
        @payment.stub(:credit_allowed).and_return(10)
        @payment.source.should_receive(:credit).with(@payment, 10)
        @payment.credit(10)
      end
    end
    context "when amount > credit_allowed" do
      it "should not call credit on the source" do
        @payment.state = 'completed'
        @payment.stub(:credit_allowed).and_return(10)
        @payment.credit(20)
        @payment.should be_completed
      end
    end
  end

  context "#save" do
    it "should call order#update!" do
      payment = Spree::Payment.create(:amount => 100, :order => order)
      order.should_receive(:update!)
      payment.save
    end

    context "when profiles are supported" do
      before { gateway.stub :payment_profiles_supported? => true }

      it "should create a payment profile" do
        gateway.should_receive :create_profile
        payment = Spree::Payment.create(:amount => 100, :order => order, :source => card, :payment_method => gateway)
      end
    end

    context "when profiles are not supported" do
      before { gateway.stub :payment_profiles_supported? => false }

      it "should not create a payment profile" do
        gateway.should_not_receive :create_profile
        payment = Spree::Payment.create(:amount => 100, :order => order, :source => card, :payment_method => gateway)
      end
    end
  end

  context "#build_source" do
    let(:payment_method) { Factory(:bogus_payment_method) }

    it "should build the payment's source" do
      params = { :amount => 100, :payment_method_id => payment_method.id,
        :source_attributes => {:year=>"2012", :month =>"1", :number => '1234567890123',:verification_value => '123'}}

      payment = Spree::Payment.new(params)
      payment.should be_valid
      payment.source.should_not be_nil
    end

    context "with the params hash ordered differently" do
      it "should build the payment's source" do
        params = {
          :source_attributes => {:year=>"2012", :month =>"1", :number => '1234567890123',:verification_value => '123'},
          :amount => 100, :payment_method_id => payment_method.id
        }

        payment = Spree::Payment.new(params)
        payment.should be_valid
        payment.source.should_not be_nil
      end
    end

    it "errors when payment source not valid" do
      params = { :amount => 100, :payment_method_id => payment_method.id,
                 :source_attributes => {:year=>"2012", :month =>"1" }}

      payment = Spree::Payment.new(params)
      payment.should_not be_valid
      payment.source.should_not be_nil
      payment.source.should have(1).error_on(:number)
      payment.source.should have(1).error_on(:verification_value)
    end
  end

end
