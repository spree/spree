require 'spec_helper'

describe Spree::Authentication::StrategyRegistry do
  let(:strategy_class) { Class.new }
  let(:other_strategy_class) { Class.new }

  describe '#add' do
    it 'registers a strategy under the given key' do
      registry = described_class.new
      registry.add(:auth0, strategy_class)
      expect(registry[:auth0]).to eq(strategy_class)
    end

    it 'symbolizes string keys' do
      registry = described_class.new
      registry.add('okta', strategy_class)
      expect(registry[:okta]).to eq(strategy_class)
    end

    it 'overwrites an existing entry under the same key' do
      registry = described_class.new(email: strategy_class)
      registry.add(:email, other_strategy_class)
      expect(registry[:email]).to eq(other_strategy_class)
    end

    it 'returns the registered class' do
      registry = described_class.new
      expect(registry.add(:auth0, strategy_class)).to eq(strategy_class)
    end
  end

  describe '#remove' do
    it 'unregisters the strategy and returns it' do
      registry = described_class.new(email: strategy_class)
      expect(registry.remove(:email)).to eq(strategy_class)
      expect(registry[:email]).to be_nil
    end

    it 'returns nil for a missing key (idempotent)' do
      registry = described_class.new
      expect(registry.remove(:unknown)).to be_nil
    end

    it 'accepts string keys' do
      registry = described_class.new(email: strategy_class)
      expect(registry.remove('email')).to eq(strategy_class)
    end
  end

  describe '#[]' do
    it 'symbolizes string lookups' do
      registry = described_class.new(email: strategy_class)
      expect(registry['email']).to eq(strategy_class)
    end

    it 'returns nil for unknown keys' do
      expect(described_class.new[:nope]).to be_nil
    end
  end

  describe '#key?' do
    it 'is true for registered keys' do
      registry = described_class.new(email: strategy_class)
      expect(registry.key?(:email)).to be true
      expect(registry.key?('email')).to be true
    end

    it 'is false for unknown keys' do
      expect(described_class.new.key?(:nope)).to be false
    end
  end

  describe '#keys / #values / #each' do
    let(:registry) { described_class.new(email: strategy_class, auth0: other_strategy_class) }

    it 'exposes the registered keys' do
      expect(registry.keys).to contain_exactly(:email, :auth0)
    end

    it 'exposes the registered classes' do
      expect(registry.values).to contain_exactly(strategy_class, other_strategy_class)
    end

    it 'iterates key/class pairs (Enumerable)' do
      expect(registry.map { |k, v| [k, v] }).to contain_exactly([:email, strategy_class], [:auth0, other_strategy_class])
    end
  end

  describe '#to_h' do
    it 'returns a copy of the underlying hash' do
      registry = described_class.new(email: strategy_class)
      copy = registry.to_h
      copy[:tampered] = Object
      expect(registry.key?(:tampered)).to be false
    end
  end
end
