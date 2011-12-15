require 'spec_helper'

describe Spree::TaxRate do

  context 'validation' do
    it { should validate_presence_of(:tax_category_id) }
  end

  context "match" do
    let(:zone) { Factory(:zone) }
    let(:order) { Factory(:order) }
    let(:tax_category) { Factory(:tax_category) }
    let(:calculator) { Spree::Calculator::FlatRate.new }

    it "should return an empty array when tax_zone is nil" do
      order.stub :tax_zone => nil
      Spree::TaxRate.match(order).should == []
    end

    it "should return an emtpy array when no rate zones match the tax_zone" do
      Spree::TaxRate.create :amount => 1, :zone => Factory(:zone, :name => 'other_zone')
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == []
    end

    it "should return the rate that matches the rate zone" do
      rate = Spree::TaxRate.create :amount => 1, :zone => zone, :tax_category => tax_category,
                                   :calculator => calculator
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == [rate]
    end

    it "should return all rates that match the rate zone" do
      rate1 = Spree::TaxRate.create :amount => 1, :zone => zone, :tax_category => tax_category,
                                    :calculator => calculator
      rate2 = Spree::TaxRate.create :amount => 2, :zone => zone, :tax_category => tax_category,
                                    :calculator => calculator
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == [rate1, rate2]
    end
  end

end
