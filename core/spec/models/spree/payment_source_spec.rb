require 'spec_helper'

describe Spree::PaymentSource, type: :model do
  it 'is an abstract class' do
    expect do
      described_class.new
    end.to raise_error(NotImplementedError)
  end
end
