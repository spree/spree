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

  describe '#build' do
    let(:buildable_class) do
      Class.new do
        attr_reader :params, :request_env, :user_class

        def initialize(params:, request_env:, user_class: nil)
          @params = params
          @request_env = request_env
          @user_class = user_class
        end
      end
    end

    it 'instantiates a bare class entry' do
      registry = described_class.new(email: buildable_class)

      built = registry.build(:email, params: { a: 1 }, request_env: { b: 2 }, user_class: String)

      expect(built).to be_a(buildable_class)
      expect(built.params).to eq(a: 1)
      expect(built.user_class).to eq(String)
    end

    # A configured factory lets one strategy class back several registrations
    # with different settings — something a bare class cannot express.
    it 'delegates to a factory entry that responds to #build' do
      factory = double('factory', build: :built_instance)
      registry = described_class.new(entra: factory)

      expect(registry.build(:entra, params: {}, request_env: {})).to eq(:built_instance)
    end

    it 'returns nil for an unregistered key' do
      expect(described_class.new.build(:nope, params: {}, request_env: {})).to be_nil
    end
  end

  describe '#describe' do
    let(:password_strategy) { double('password strategy', kind: :password, label: nil) }
    let(:redirect_strategy) do
      double('redirect strategy', kind: :redirect, label: 'Entra ID', authorization_url: 'https://idp/auth?state=xyz')
    end

    it 'describes a password provider without a label or URL' do
      registry = described_class.new(email: password_strategy)

      expect(registry.describe).to eq([{ key: 'email', kind: 'password' }])
    end

    it 'describes a redirect provider with its label and authorization URL' do
      registry = described_class.new(entra: redirect_strategy)

      expect(registry.describe { 'xyz' }).to eq(
        [{ key: 'entra', kind: 'redirect', label: 'Entra ID', authorization_url: 'https://idp/auth?state=xyz' }]
      )
    end

    # Each redirect provider gets its own state so one cannot be replayed against
    # another provider's callback.
    it 'mints a state per redirect provider' do
      registry = described_class.new(email: password_strategy, entra: redirect_strategy)
      seen = []

      registry.describe { |key| seen << key; "state-for-#{key}" }

      expect(seen).to eq([:entra])
      expect(redirect_strategy).to have_received(:authorization_url).with(state: 'state-for-entra')
    end

    it 'degrades an entry that predates the kind/label contract to a password provider' do
      bare = Class.new
      registry = described_class.new(legacy: bare)

      expect(registry.describe).to eq([{ key: 'legacy', kind: 'password' }])
    end

    # A misconfigured or unreachable provider must not take down the login page
    # for every other provider.
    it 'omits the URL when building it raises, keeping other providers usable' do
      broken = double('broken strategy', kind: :redirect, label: 'Broken')
      allow(broken).to receive(:authorization_url).and_raise(StandardError, 'unreachable')
      registry = described_class.new(email: password_strategy, broken: broken)

      described = registry.describe

      expect(described).to include({ key: 'email', kind: 'password' })
      expect(described.last).to eq(key: 'broken', kind: 'redirect', label: 'Broken')
    end
  end
end
