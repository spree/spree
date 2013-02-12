require 'spec_helper'

describe Spree::StockLocation do
  subject { create(:stock_location) }

  it 'determines the count_on_hand for a variant' do
    variant = subject.stock_items.first.variant
    subject.count_on_hand(variant.id).should eq 10
  end
end
