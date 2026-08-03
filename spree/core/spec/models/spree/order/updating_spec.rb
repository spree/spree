require 'spec_helper'

describe Spree::Order, type: :model do
  let(:order) { create(:order) }

  context '#recalculate_totals!' do
    let(:line_items) { create_list(:line_item, 1, amount: 5) }

    it 'persists recalculated totals' do
      expect { order.recalculate_totals! }.to change { order.reload.updated_at }
    end
  end
end
