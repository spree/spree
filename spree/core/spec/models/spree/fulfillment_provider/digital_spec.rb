require 'spec_helper'

describe Spree::FulfillmentProvider::Digital, type: :model do
  subject(:provider) { described_class.new }

  it 'auto-fulfills on order completion' do
    expect(provider.auto_fulfill?).to be(true)
  end

  describe '#create_fulfillment' do
    let(:digital_product) { create(:digital_product) }
    let(:variant) { create(:variant, product: digital_product, digitals: [create(:digital_asset), create(:digital_asset)]) }
    let(:order) { create(:order) }
    let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 3) }
    let!(:fulfillment) { create(:fulfillment, order: order) }

    before do
      fulfillment.fulfillment_items.create!(order: order, line_item: line_item, variant: variant, quantity: 3)
    end

    it 'creates one link per digital asset per unit of quantity' do
      provider.create_fulfillment(fulfillment)

      expect(line_item.digital_links.reload.group(:digital_asset_id).count.values).to eq([3, 3])
    end

    it 'is idempotent' do
      provider.create_fulfillment(fulfillment)
      expect { provider.create_fulfillment(fulfillment) }.not_to change { line_item.digital_links.reload.count }
    end

    it 'tops up missing links only' do
      provider.create_fulfillment(fulfillment)
      line_item.digital_links.reload.first.destroy!

      expect { provider.create_fulfillment(fulfillment) }.to change { line_item.digital_links.reload.count }.by(1)
    end
  end
end
