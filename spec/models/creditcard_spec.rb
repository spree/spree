require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Creditcard do
  before(:each) do
    @creditcard = Creditcard.new(:number => "4111111111111111", 
                                 :month => "12",
                                 :year => "2010",
                                 :verification_value => "123",
                                 :first_name => "Sean",
                                 :last_name => "Schofield")
  end
    
  it "should correctly assign the type of credit card based on the number" do
    @creditcard.save
    @creditcard.cc_type.should == "visa"
  end  

  it "should store the creditcard number if :store_cc => true" do
    Spree::Config.set(:store_cc => true)
    @creditcard.save
    @creditcard = Creditcard.find(@creditcard.id)
    @creditcard.number.should == "4111111111111111"
  end
  it "should not store the creditcard number if :store_cc => false" do
    Spree::Config.set(:store_cc => false)
    @creditcard.save
    @creditcard = Creditcard.find(@creditcard.id)
    @creditcard.number.should be_nil
  end
  it "should store the verification_value if :store_cvv => true" do
    Spree::Config.set(:store_cvv => true)
    @creditcard.save
    @creditcard = Creditcard.find(@creditcard.id)
    @creditcard.verification_value.should == "123"
  end
  it "should not store the verification_value if :store_cvv => false" do
    Spree::Config.set(:store_cvv => false)
    @creditcard.save
    @creditcard = Creditcard.find(@creditcard.id)
    @creditcard.verification_value.should be_nil
  end
  
end
