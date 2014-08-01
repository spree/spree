require 'spec_helper'

describe Spree::Calculator::TieredPercent do
  let(:calculator) { Spree::Calculator::TieredPercent.new }

  describe "#valid?" do
    subject { calculator.valid? }
    context "when there are more than 5 tiers" do
      before do
        calculator.preferred_buckets = {
          (0..100) => 10,
          (100..200) => 15,
          (200..300) => 20,
          (300..400) => 25,
          (400..500) => 30,
          (500..600) => 35
        }
      end
      it { should be false }
    end
  end

  describe "#compute" do
    let(:line_item) { mock_model Spree::LineItem, amount: amount }
    before do
      calculator.preferred_buckets = {
        (0..100) => 10,
        (100..200) => 15,
        (200..300) => 20
      }
    end
    subject { calculator.compute(line_item) }
    context "when amount falls within the first tier" do
      let(:amount) { 50 }
      it { should eq 5 }
    end
    context "when amount falls within the second tier" do
      let(:amount) { 150 }
      it { should eq 22 }
    end
    context "when amount falls in two tiers" do
      let(:amount) { 100 }
      it { should eq 10 }
    end
    context "when amount falls outside of all tiers" do
      let(:amount) { 500 }
      it { should eq 0 }
    end
  end
end
