require 'spec_helper'

# Only the backfill is exercised: changing the default is DDL, and MySQL
# commits implicitly on DDL, dropping the savepoint the example runs inside.
RSpec.describe 'SetDefaultFeeTotalOnSpreeOrders migration' do
  let(:migration) do
    require Spree::Core::Engine.root.join('db', 'migrate', '20261124000001_set_default_fee_total_on_spree_orders.rb')
    SetDefaultFeeTotalOnSpreeOrders.new
  end

  it 'gives an order holding no fee total the sum of its fees' do
    with_fees = create(:order)
    create(:fee, order: with_fees, amount: 3)
    create(:fee, order: with_fees, amount: 4.5)
    without_fees = create(:order)
    already_set = create(:order)
    create(:fee, order: already_set, amount: 9)
    Spree::Order.where(id: [with_fees.id, without_fees.id]).update_all(fee_total: nil)
    already_set.update_columns(fee_total: 2)

    migration.send(:backfill)

    expect(with_fees.reload.fee_total).to eq(7.5)
    expect(without_fees.reload.fee_total).to eq(0)
    expect(already_set.reload.fee_total).to eq(2)
  end
end
