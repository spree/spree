shared_examples_for 'an adjustment line' do
  let(:factory) { described_class.name.demodulize.underscore.to_sym }

  describe 'adjustable validation' do
    it 'requires a line item or a fulfillment' do
      line = build(factory, line_item: nil, fulfillment: nil)

      expect(line).not_to be_valid
      expect(line.errors[:base]).to include(Spree.t('errors.messages.must_belong_to_line_item_or_fulfillment'))
    end

    it 'rejects both adjustables at once' do
      line = build(factory, fulfillment: build(:shipment))

      expect(line).not_to be_valid
      expect(line.errors[:base]).to include(Spree.t('errors.messages.cannot_belong_to_both_adjustables'))
    end
  end

  describe '#adjustable' do
    it 'resolves to the line item or the fulfillment' do
      line_item = build(:line_item)
      shipment = build(:shipment)

      expect(build(factory, line_item: line_item).adjustable).to eq(line_item)
      expect(build(factory, line_item: nil, fulfillment: shipment).adjustable).to eq(shipment)
    end
  end
end
