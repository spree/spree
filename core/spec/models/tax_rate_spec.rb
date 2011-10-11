require 'spec_helper'

describe TaxRate do

  context 'validation' do
    let(:zone) { Zone.new }

    it { should have_valid_factory(:tax_rate) }

    it "should validate presence of amount" do
      rate = TaxRate.new :zone => zone, :amount => nil
      rate.save.should be_false
    end

    it "should validate presence of zone" do
      rate = TaxRate.new :zone => nil, :amount => 1
      rate.save.should be_false
    end
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
    it "should returnn all matches in the event of multiple matches" do
      rate1.stub_chain :zone, :include? => true
      rate2.stub_chain :zone, :include? => true
      rate1.stub :amount => 10
      rate2.stub :amount => 5
      TaxRate.match(address).should == [rate1, rate2]
    end
  end

  context "default" do
    let(:category) { Factory :tax_category, :tax_rates => [] }
    let(:rate) { Factory :tax_rate, :amount => 0.1, :tax_category => category}

    it "should return zero with no default category" do
      TaxCategory.any_instance.should_not_receive(:effective_amount)
      TaxRate.default.should == 0
    end

    it "should return rate when default category is set" do
      category.update_attribute(:is_default, true) 
      TaxCategory.any_instance.should_receive(:effective_amount)
      TaxRate.default
    end

  end
end
