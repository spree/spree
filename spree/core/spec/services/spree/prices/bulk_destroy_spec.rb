require 'spec_helper'

RSpec.describe Spree::Prices::BulkDestroy do
  let(:price_list) { create(:price_list, store: @default_store) }
  let(:variant) { create(:variant, price: 10.00) }

  def rung(quantity, amount)
    create(:price, variant: variant, currency: 'USD', price_list: price_list, min_quantity: quantity, amount: amount)
  end

  let!(:bottom) { rung(1, 12.00) }
  let!(:break_above_base) { rung(100, 11.00) }

  # One row at a time, the bottom rung would be refused for stranding the
  # break above it.
  it 'deletes a bottom rung together with the breaks above it' do
    result = described_class.call(prices: [bottom, break_above_base])

    expect(result).to be_success
    expect(result.value).to eq(price_count: 2)
    expect(Spree::Price.where(variant: variant, price_list: price_list)).to be_empty
  end

  it 'refuses the whole batch when what it leaves rises' do
    other = create(:price, variant: variant, currency: 'EUR', price_list: price_list, amount: 9.00)

    result = described_class.call(prices: [other, bottom])

    expect(result).to be_failure
    expect(result.error.value[:rising_ladders]).to contain_exactly(
      include(min_quantity: 100, amount: BigDecimal('11.00'), floor: BigDecimal('10.00'))
    )
    expect(other.reload.deleted_at).to be_nil
    expect(bottom.reload.deleted_at).to be_nil
  end
end
