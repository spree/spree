require 'spec_helper'

describe Spree::TaxCategory do
  context "shoulda validations" do
    it { should have_many(:tax_rates) }
    it { should validate_presence_of(:name) }
    it { should have_valid_factory(:tax_category) }

    context 'uniquness validation' do
      before do
        Factory(:tax_category)
      end
      it { should validate_uniqueness_of(:name) }
    end
  end

  context 'effective_amount' do
    let(:rate) { Factory :tax_rate, :amount => 0.1}
    let(:category) { Factory :tax_category, :tax_rates => [rate] }

    it "should return nil when default_country is not included in zone" do
      rate.zone.stub(:include? => false)
      category.effective_amount.should be_nil
    end

    it "should return amount when default_country is included in zone" do
      rate.zone.stub(:include? => true)
      category.effective_amount.should == rate.amount
    end

    it "should return nil when address supplied is not included in zone" do
      rate.zone.stub(:include? => false)
      category.effective_amount(Spree::Address.new).should be_nil
    end

    it "should return amount when address supplied is included in zone" do
      rate.zone.stub(:include? => true)
      category.effective_amount(Spree::Address.new).should == rate.amount
    end

  end


end
