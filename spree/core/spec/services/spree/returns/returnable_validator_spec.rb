require 'spec_helper'

RSpec.describe Spree::Returns::ReturnableValidator do
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

  it 'lets a customer return a shipped unit sold as returnable' do
    expect(open_return).to be_success
  end

  context 'when the line was sold as non-returnable' do
    before { unit.line_item.update_columns(returnable: false) }

    it 'rejects a customer return, naming the item' do
      result = open_return

      expect(result).to be_failure
      expect(result.error.value.details[:base].first[:error]).to eq(:not_returnable)
      expect(result.error.to_s).to include(unit.variant.name)
      expect(order.reload.returns).to be_empty
    end

    it 'lets staff open one anyway' do
      expect(open_return(created_by: create(:admin_user))).to be_success
    end
  end

  # The flag the customer bought under is the one that counts.
  it 'reads the frozen line, not the live catalogue' do
    unit.variant.product.update_columns(returnable: false)

    expect(open_return).to be_success
  end

  context 'when the unit has not shipped' do
    let(:order) { create(:order_ready_to_ship, store: store) }

    it 'rejects a customer return' do
      result = open_return

      expect(result).to be_failure
      expect(result.error.value.details[:base].first[:error]).to eq(:not_shipped)
    end
  end

  # An exchange's replacement rides on the original line but is another
  # variant, so its own variant decides.
  describe 'a replacement unit' do
    it 'is judged by its own variant' do
      replacement = create(:variant, product: unit.variant.product)
      replacement.update!(returnable: false)
      unit.update_columns(variant_id: replacement.id)

      expect(unit.reload.returnable?).to be(false)
    end
  end
end
