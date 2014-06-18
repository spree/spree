require 'spec_helper'

module Spree
  module Stock
    describe AvailabilityValidator, :type => :model do
      let!(:line_item) { double(quantity: 5, variant_id: 1, variant: double.as_null_object, errors: double('errors'), inventory_units: []) }

      subject { described_class.new }

      it 'should be valid when supply is sufficient' do
        allow_any_instance_of(Stock::Quantifier).to receive_messages(can_supply?: true)
        expect(line_item).not_to receive(:errors)
        subject.validate(line_item)
      end

      it 'should be invalid when supply is insufficent' do
        allow_any_instance_of(Stock::Quantifier).to receive_messages(can_supply?: false)
        expect(line_item.errors).to receive(:[]).with(:quantity).and_return []
        subject.validate(line_item)
      end

      it 'should consider existing inventory_units sufficient' do
        allow_any_instance_of(Stock::Quantifier).to receive_messages(can_supply?: false)
        expect(line_item).not_to receive(:errors)
        allow(line_item).to receive_messages(inventory_units: [double] * 5)
        subject.validate(line_item)
      end

      it 'should be valid when the quantity is zero' do
        expect(line_item).to receive(:quantity).and_return(0)
        expect(line_item.errors).to_not receive(:[]).with(:quantity)
        subject.validate(line_item)
      end
    end
  end
end
