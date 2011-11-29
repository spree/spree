require 'spec_helper'

describe Spree::TaxRate do

  context 'validation' do
    it { should have_valid_factory(:tax_rate) }
    it { should validate_presence_of(:tax_category_id) }
  end

  context "match" do
    let(:zone) { Factory(:zone) }
    let(:order) { Factory(:order) }

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
      rate = Spree::TaxRate.create :amount => 1, :zone => zone
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == [rate]
    end

    it "should return all rates that match the rate zone" do
      rate1 = Spree::TaxRate.create :amount => 1, :zone => zone
      rate2 = Spree::TaxRate.create :amount => 2,:zone => zone
      order.stub :tax_zone => zone
      Spree::TaxRate.match(order).should == [rate1, rate2]
    end
  end

  context "default" do
    let(:category) { Factory :tax_category, :tax_rates => [] }
    let(:rate) { Factory :tax_rate, :amount => 0.1, :tax_category => category}

    it "should return zero with no default category" do
      Spree::TaxCategory.any_instance.should_not_receive(:effective_amount)
      Spree::TaxRate.default.should == 0
    end

    it "should return rate when default category is set" do
      category.update_attribute(:is_default, true)
      Spree::TaxCategory.any_instance.should_receive(:effective_amount)
      Spree::TaxRate.default
    end

  end
end
