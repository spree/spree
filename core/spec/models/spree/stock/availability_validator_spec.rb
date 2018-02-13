require 'spec_helper'

module Spree
  module Stock
    describe AvailabilityValidator, type: :model do
      subject { described_class.new }

      let!(:line_item) { double(quantity: 5, variant_id: 1, variant: double.as_null_object, errors: double('errors'), inventory_units: []) }
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_units) { [inventory_unit] }

      before do
        allow(inventory_unit).to receive_messages(pending?: false)
        allow(inventory_unit).to receive_messages(quantity: 5)
      end

      it 'is valid when supply is sufficient' do
        allow_any_instance_of(Stock::Quantifier).to receive_messages(can_supply?: true)
        expect(line_item).not_to receive(:errors)
        subject.validate(line_item)
      end

      it 'is invalid when supply is insufficent' do
        allow_any_instance_of(Stock::Quantifier).to receive_messages(can_supply?: false)
        expect(line_item.errors).to receive(:[]).with(:quantity).and_return []
        subject.validate(line_item)
      end

      it 'considers existing inventory_units sufficient' do
        allow_any_instance_of(Stock::Quantifier).to receive_messages(can_supply?: false)
        expect(line_item).not_to receive(:errors)
        allow(line_item).to receive_messages(inventory_units: inventory_units)
        subject.validate(line_item)
      end

      it 'is valid when the quantity is zero' do
        expect(line_item).to receive(:quantity).and_return(0)
        expect(line_item.errors).not_to receive(:[]).with(:quantity)
        subject.validate(line_item)
      end
    end
  end
end
