require 'spec_helper'

module Spree
  module Stock
    describe AvailabilityValidator do
      let!(:line_item) { double(quantity: 5, variant_id: 1, variant: double.as_null_object, errors: double('errors'), inventory_units: []) }

      subject { described_class.new }

      it 'should be valid when supply is sufficient' do
        Stock::Quantifier.any_instance.stub(can_supply?: true)
        line_item.should_not_receive(:errors)
        subject.validate(line_item)
      end

      it 'should be invalid when supply is insufficent' do
        Stock::Quantifier.any_instance.stub(can_supply?: false)
        line_item.errors.should_receive(:[]).with(:quantity).and_return []
        subject.validate(line_item)
      end

      it 'should consider existing inventory_units sufficient' do
        Stock::Quantifier.any_instance.stub(can_supply?: false)
        line_item.should_not_receive(:errors)
        line_item.stub(inventory_units: [double] * 5)
        subject.validate(line_item)
      end
    end
  end
end
