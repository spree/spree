require 'spec_helper'

RSpec.describe Spree::Workflows::Context do
  # Context is now just HashWithIndifferentAccess
  it 'is an alias for HashWithIndifferentAccess' do
    expect(described_class).to eq(ActiveSupport::HashWithIndifferentAccess)
  end

  describe 'basic usage' do
    it 'accepts initial data' do
      context = described_class.new(order_id: 1, name: 'Test')

      expect(context[:order_id]).to eq(1)
      expect(context[:name]).to eq('Test')
    end

    it 'supports indifferent access' do
      context = described_class.new

      context['order_id'] = 1
      expect(context[:order_id]).to eq(1)
    end

    it 'supports merge!' do
      context = described_class.new(a: 1)
      context.merge!(b: 2, c: 3)

      expect(context[:a]).to eq(1)
      expect(context[:b]).to eq(2)
      expect(context[:c]).to eq(3)
    end

    it 'supports standard hash operations' do
      context = described_class.new(order_id: 1)

      expect(context.key?(:order_id)).to be true
      expect(context.fetch(:order_id)).to eq(1)
      expect(context.fetch(:missing, 'default')).to eq('default')
      expect(context.empty?).to be false
      expect(context.keys).to eq(['order_id'])
    end
  end
end
