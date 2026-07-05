# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Preferences::Masking do
  describe '.mask' do
    it 'returns nil for blank values' do
      expect(described_class.mask(nil)).to be_nil
      expect(described_class.mask('')).to be_nil
    end

    it 'masks long secrets, preserving only the last 4 characters' do
      expect(described_class.mask('sk_test_abcdef1234')).to eq('••••1234')
    end

    it 'masks short secrets without exposing the whole value when shorter than 4' do
      expect(described_class.mask('abc')).to eq('••••abc')
    end

    it 'coerces non-string values to a string before masking' do
      expect(described_class.mask(1234567890)).to eq('••••7890')
    end
  end

  describe '.masked?' do
    it 'detects a masked string by its leading token' do
      expect(described_class.masked?('••••1234')).to be true
    end

    it 'returns false for plaintext values' do
      expect(described_class.masked?('sk_test_abcdef1234')).to be false
      expect(described_class.masked?('')).to be false
      expect(described_class.masked?(nil)).to be false
      expect(described_class.masked?(42)).to be false
    end
  end

  describe '.serialize' do
    # A throwaway Preferable — keeps the test focused on the masking
    # helper instead of coupling to whichever production model happens
    # to expose a :password preference today. Provides its own
    # `preferences` hash since Preferable is normally mixed into an
    # ActiveRecord model that supplies the serialized column.
    let(:preferable_class) do
      Class.new do
        include Spree::Preferences::Preferable
        include Spree::PreferenceSchema

        preference :api_key,        :string,   default: 'PUBLIC123'
        preference :api_secret,     :password, default: 'SECRET456'
        preference :ratio,          :decimal,  default: 0.5
        preference :enabled,        :boolean,  default: true

        def preferences
          @preferences ||= {}
        end

        def self.name
          'TestPreferable'
        end
      end
    end

    let(:preferable) { preferable_class.new }

    it 'returns {} when the receiver is nil' do
      expect(described_class.serialize(nil)).to eq({})
    end

    # Wire shape: keys are stringified so the output matches what JSON
    # consumers expect, regardless of whether the underlying preference
    # hash uses symbol or string keys internally.
    it 'returns plaintext for non-password preferences with string keys' do
      preferable.set_preference(:api_key, 'pk_live_visible')
      preferable.set_preference(:ratio, 0.25)
      preferable.set_preference(:enabled, false)

      result = described_class.serialize(preferable)

      expect(result['api_key']).to eq('pk_live_visible')
      expect(result['ratio']).to eq(0.25)
      expect(result['enabled']).to be false
    end

    it 'masks password-typed preferences' do
      preferable.set_preference(:api_secret, 'sk_live_extremely_secret_value')

      expect(described_class.serialize(preferable)['api_secret']).to eq('••••alue')
    end

    it 'returns nil for unset password preferences (no default leakage)' do
      preferable.preferences.delete(:api_secret)

      result = described_class.serialize(preferable)

      expect(result.fetch('api_secret')).to be_nil
      # Sanity check: the unmasked default would have leaked here.
      expect(result.fetch('api_secret')).not_to eq('SECRET456')
    end
  end
end
