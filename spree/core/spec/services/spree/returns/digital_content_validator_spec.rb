require 'spec_helper'

RSpec.describe Spree::Returns::DigitalContentValidator do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }
  let(:unit) { order.fulfillment_items.first }

  def open_return(created_by: nil)
    Spree::Returns::Create.call(order: order, items: [{ fulfillment_item: unit, quantity: 1 }], created_by: created_by)
  end

  before do
    Spree.hooks.register('returns.create.validate', described_class.name)
    Spree.hooks.register('exchanges.create.validate', described_class.name)
  end

  it 'is registered on the create workflows' do
    expect(Spree.hooks.for('returns.create.validate').map(&:class)).to include(described_class)
    expect(Spree.hooks.for('exchanges.create.validate').map(&:class)).to include(described_class)
  end

  it 'leaves physical goods alone' do
    expect(open_return).to be_success
  end

  context 'when the unit was delivered digitally' do
    before do
      digital = create(:digital_delivery_method)
      unit.fulfillment.delivery_rates.update_all(delivery_method_id: digital.id)
    end

    it 'rejects a customer return' do
      result = open_return

      expect(result).to be_failure
      expect(result.error.value.details[:base].first[:error]).to eq(:digital_content)
    end

    it 'lets staff open one anyway' do
      expect(open_return(created_by: create(:admin_user))).to be_success
    end
  end
end
