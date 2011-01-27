require File.dirname(__FILE__) + '/../spec_helper'

describe TaxRate do

  context 'validation' do
    it { should have_valid_factory(:tax_rate) }
  end

  context "match" do
    let(:rate1) { TaxRate.new }
    let(:rate2) { TaxRate.new }
    let (:address) { mock_model Address }

    before { TaxRate.stub(:all => [rate1, rate2]) }

    it "should be nil if none of the zones include the address" do
      rate1.stub_chain :zone, :include? => false
      rate2.stub_chain :zone, :include? => false
      TaxRate.match(address).should == []
    end
    it "should return a rate if its zone includes the address" do
      rate1.stub_chain :zone, :include? => false
      rate2.stub_chain :zone, :include? => true
      TaxRate.match(address).should == [rate2]
    end
    it "should use the rate with the highest amount in the event of multiple matches" do
      rate1.stub_chain :zone, :include? => true
      rate2.stub_chain :zone, :include? => true
      rate1.stub :amount => 10
      rate2.stub :amount => 5
      TaxRate.match(address).should == [rate1, rate2]
    end
  end
end
