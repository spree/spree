require 'spec_helper'

RSpec.describe Spree::DigitalAssetProvider::Base do
  describe '.setting / .settings_schema' do
    let(:provider) do
      Class.new(described_class) do
        setting :pool_name, :string
        setting :region, :select, in: %w[us eu], default: 'us'
        setting :auto_revoke, :boolean, default: false
      end
    end

    it 'exposes each declared setting in the wire shape the form renders' do
      schema = provider.settings_schema

      expect(schema).to contain_exactly(
        { key: :pool_name, type: :string },
        { key: :region, type: :select, default: 'us', in: %w[us eu] },
        { key: :auto_revoke, type: :boolean, default: false }
      )
    end

    it 'rejects an unknown field type' do
      expect { Class.new(described_class) { setting :x, :date } }
        .to raise_error(ArgumentError, /unknown setting type/)
    end

    it 'is empty for a provider that declares nothing' do
      expect(Class.new(described_class).settings_schema).to eq([])
    end

    it 'inherits a parent provider settings' do
      child = Class.new(provider) { setting :extra, :string }

      expect(child.settings_schema.map { |field| field[:key] })
        .to include(:pool_name, :region, :auto_revoke, :extra)
    end
  end
end
