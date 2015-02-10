require 'spec_helper'

describe Spree::OrderPopulator, :type => :model do
  let(:order) { double('Order') }
  subject { Spree::OrderPopulator.new(order, "USD") }

  context "with stubbed out find_variant" do
    let(:variant) { double('Variant', name: "T-Shirt", options_text: "Size: M") }

    before do
      allow(Spree::Variant).to receive(:find).and_return(variant)
      expect(order).to receive(:contents).at_least(:once).and_return(Spree::OrderContents.new(self))
    end

    context "can populate an order" do
      it "can take a list of variants with quantites and add them to the order" do
        expect(order.contents).to receive(:add).with(variant, 5, currency: subject.currency).and_return(double.as_null_object)
        subject.populate(2, 5)
      end
    end

    context 'with an invalid variant' do
      let(:line_item) { build(:line_item) }

      before do
        allow(order.contents).to receive(:add).and_raise(ActiveRecord::RecordInvalid, line_item)
      end

      it 'has some errors' do
        subject.populate(2, 5)
        expect(subject.errors).to_not be_empty
      end
    end
  end
end
