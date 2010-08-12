require 'spec_helper'

describe Payment do

  # let(:payment) { Payment.new }
  before(:each) do
    @payment = Payment.new
    @payment.source = Creditcard.new
    @payment.stub!(:valid?).and_return(true)
    @payment.stub!(:check_payments).and_return(nil)
  end

  context "#process!" do
   
    context "when state is new" do
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

  end

end
