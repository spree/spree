require 'spec_helper'

RSpec.describe Spree::Preferences::RuntimeConfiguration do
  # App-level settings can be backed by an environment variable so operators
  # configure a deployment without editing Ruby.
  let(:configuration_class) do
    Class.new(described_class) do
      preference :plain_setting, :string, default: 'coded'
      preference :env_setting, :string, default: 'coded', env: 'SPREE_SPEC_ENV_SETTING'
      preference :boolean_setting, :boolean, default: true, env: 'SPREE_SPEC_BOOLEAN'
      preference :integer_setting, :integer, default: 3600, env: 'SPREE_SPEC_INTEGER'
      preference :decimal_setting, :decimal, default: 0, env: 'SPREE_SPEC_DECIMAL'
      preference :array_setting, :array, default: [], env: 'SPREE_SPEC_ARRAY'
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

  # Env vars arrive as strings, so without coercion SPREE_X=false would be the
  # truthy String "false" and SPREE_X=30 the String "30".
  describe 'type coercion' do
    def with_env(name, value)
      stub_const('ENV', ENV.to_h.merge(name => value))
      configuration_class.new
    end

    context 'with a boolean setting' do
      %w[true 1 yes on TRUE Yes ON].each do |spelling|
        it "reads #{spelling.inspect} as true" do
          expect(with_env('SPREE_SPEC_BOOLEAN', spelling)[:boolean_setting]).to be(true)
        end
      end

      %w[false 0 no off FALSE No Off].each do |spelling|
        it "reads #{spelling.inspect} as false" do
          expect(with_env('SPREE_SPEC_BOOLEAN', spelling)[:boolean_setting]).to be(false)
        end
      end

      it 'raises on a value that is neither' do
        expect { with_env('SPREE_SPEC_BOOLEAN', 'nope')[:boolean_setting] }.to raise_error(
          Spree::Preferences::InvalidEnvironmentValue, /SPREE_SPEC_BOOLEAN="nope"/
        )
      end
    end

    context 'with an integer setting' do
      it 'reads a number as an Integer' do
        expect(with_env('SPREE_SPEC_INTEGER', '30')[:integer_setting]).to eq(30)
      end

      # `.to_i` would silently turn this typo into 0 and then into the default.
      it 'raises on a value that is not a number' do
        expect { with_env('SPREE_SPEC_INTEGER', '3O0')[:integer_setting] }.to raise_error(
          Spree::Preferences::InvalidEnvironmentValue, /SPREE_SPEC_INTEGER="3O0"/
        )
      end

      it 'raises rather than truncating a decimal' do
        expect { with_env('SPREE_SPEC_INTEGER', '1.5')[:integer_setting] }.to raise_error(
          Spree::Preferences::InvalidEnvironmentValue
        )
      end
    end

    context 'with a decimal setting' do
      it 'reads a number as a BigDecimal' do
        expect(with_env('SPREE_SPEC_DECIMAL', '1.5')[:decimal_setting]).to eq(BigDecimal('1.5'))
      end

      it 'raises on a value that is not a number' do
        expect { with_env('SPREE_SPEC_DECIMAL', 'abc')[:decimal_setting] }.to raise_error(
          Spree::Preferences::InvalidEnvironmentValue, /SPREE_SPEC_DECIMAL="abc"/
        )
      end
    end

    context 'with an array setting' do
      it 'splits on commas and strips whitespace' do
        expect(with_env('SPREE_SPEC_ARRAY', 'a, b ,c')[:array_setting]).to eq(%w[a b c])
      end
    end

    it 'leaves a string setting as it is' do
      expect(with_env('SPREE_SPEC_ENV_SETTING', 'false')[:env_setting]).to eq('false')
    end

    it 'falls back to the typed default when the variable is unset' do
      configuration = with_env('SPREE_SPEC_ENV_SETTING', 'ignored')

      expect(configuration[:integer_setting]).to eq(3600)
      expect(configuration[:boolean_setting]).to be(true)
    end

    it 'prefers an explicitly assigned value over the environment' do
      configuration = with_env('SPREE_SPEC_INTEGER', '30')
      configuration.integer_setting = 99

      expect(configuration[:integer_setting]).to eq(99)
    end

    describe '.validate_env!' do
      it 'raises at boot for a malformed value' do
        configuration = with_env('SPREE_SPEC_INTEGER', 'abc')

        expect { configuration_class.validate_env!(configuration) }.to raise_error(
          Spree::Preferences::InvalidEnvironmentValue
        )
      end

      it 'passes over a malformed value that an explicit assignment overrides' do
        configuration = with_env('SPREE_SPEC_INTEGER', 'abc')
        configuration.integer_setting = 99

        expect { configuration_class.validate_env!(configuration) }.not_to raise_error
      end
    end
  end
end
