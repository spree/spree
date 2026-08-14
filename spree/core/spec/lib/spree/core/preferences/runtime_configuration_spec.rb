require 'spec_helper'

RSpec.describe Spree::Preferences::RuntimeConfiguration do
  # App-level settings can be backed by an environment variable so operators
  # configure a deployment without editing Ruby.
  let(:configuration_class) do
    Class.new(described_class) do
      preference :plain_setting, :string, default: 'coded'
      preference :env_setting, :string, default: 'coded', env: 'SPREE_SPEC_ENV_SETTING'
    end
  end

  subject(:configuration) { configuration_class.new }

  context 'when the environment variable is set' do
    before { stub_const('ENV', ENV.to_h.merge('SPREE_SPEC_ENV_SETTING' => 'from-env')) }

    it 'reads the environment over the coded default' do
      expect(configuration[:env_setting]).to eq('from-env')
    end

    it 'still prefers an explicitly assigned value' do
      configuration.env_setting = 'explicit'

      expect(configuration[:env_setting]).to eq('explicit')
    end

    it 'leaves settings without an env option alone' do
      expect(configuration[:plain_setting]).to eq('coded')
    end
  end

  context 'when the environment variable is absent' do
    before { stub_const('ENV', ENV.to_h.except('SPREE_SPEC_ENV_SETTING')) }

    it 'falls back to the coded default' do
      expect(configuration[:env_setting]).to eq('coded')
    end

    it 'treats a blank value as unset' do
      stub_const('ENV', ENV.to_h.merge('SPREE_SPEC_ENV_SETTING' => ''))

      expect(configuration[:env_setting]).to eq('coded')
    end
  end
end
