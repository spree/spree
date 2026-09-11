require 'spec_helper'

describe Spree::StockLevels::Correct do
  subject(:stock_level) { create(:stock_level, adjust_count_on_hand: false) }

  before { stock_level.update_column(:count_on_hand, 10) }

  def correct(**arguments)
    described_class.call(stock_level: stock_level, **arguments)
  end

  it 'sets the shelf to a counted figure and records the difference' do
    result = correct(count_on_hand: 40, reason: 'count')

    expect(result).to be_success
    expect(stock_level.reload.count_on_hand).to eq(40)
    movement = stock_level.stock_movements.adjusted.sole
    expect(movement.quantity).to eq(30)
    expect(movement.reason).to eq('Count')
  end

  # The point of an adjustment: the caller knows the difference without having
  # read a count that may since have moved.
  it 'moves the shelf by a difference against what it holds now' do
    stock_level.update_column(:count_on_hand, 12)

    expect(correct(adjustment: -3)).to be_success
    expect(stock_level.reload.count_on_hand).to eq(9)
    expect(stock_level.stock_movements.adjusted.sole.quantity).to eq(-3)
  end

  it 'refuses a count and a difference in the same call' do
    result = correct(count_on_hand: 5, adjustment: 1)

    expect(result).to be_failure
    expect(result.error.to_s).to include('not both')
    expect(stock_level.reload.count_on_hand).to eq(10)
  end

  # `to_i` reads "abc" as zero, and a zero here is not a no-op — it writes the
  # whole shelf off.
  it 'refuses a figure it cannot read rather than obeying it' do
    expect(correct(count_on_hand: 'forty')).to be_failure
    expect(correct(adjustment: 'two')).to be_failure

    expect(stock_level.reload.count_on_hand).to eq(10)
    expect(stock_level.stock_movements.adjusted).to be_empty
  end

  it 'writes nothing when the shelf is already at the figure' do
    expect(correct(count_on_hand: 10)).to be_success
    expect(stock_level.stock_movements.adjusted).to be_empty
  end

  it 'labels an unlabelled correction in English' do
    correct(count_on_hand: 11)

    expect(stock_level.stock_movements.adjusted.sole.reason).to eq('Manual adjustment')
  end

  # An integration's own wording is not Spree's to police.
  it 'keeps wording it does not recognise' do
    correct(count_on_hand: 11, reason: 'Counted by the night shift')

    expect(stock_level.stock_movements.adjusted.sole.reason).to eq('Counted by the night shift')
  end
end
