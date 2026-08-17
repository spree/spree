require 'spec_helper'
RSpec.describe 'flat fee cannot charge delivery' do
  let(:store) { @default_store }

  it 'refuses the combination' do
    rate = build(:commission_rate, :fixed, store: store, include_shipping: true)
    puts "valid?: #{rate.valid?} #{rate.errors.full_messages.inspect}"
    expect(rate).not_to be_valid
  end

  it 'still allows a percentage to charge delivery' do
    expect(build(:commission_rate, store: store, include_shipping: true)).to be_valid
  end
end
