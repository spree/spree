require 'spec_helper'

RSpec.describe Spree::Integration, type: :model do
  subject(:integration) { build(:integration) }

  it { is_expected.to be_valid }

  describe 'type registration' do
    let(:registered_class) do
      Class.new(described_class) do
        def self.name = 'TestIntegrations::Registered'
      end
    end

    before { stub_const('TestIntegrations::Registered', registered_class) }

    it 'accepts any type while no integrations are registered' do
      expect(build(:integration, type: 'Spree::Integration')).to be_valid
    end

    it 'rejects unregistered types once the registry is populated' do
      Spree.integrations << 'TestIntegrations::Registered'

      expect(build(:integration, type: 'TestIntegrations::Registered')).to be_valid
      expect(build(:integration, type: 'Spree::Integration')).not_to be_valid
    ensure
      Spree.integrations.delete('TestIntegrations::Registered')
    end

    it 'keeps existing rows loadable after their gem is uninstalled' do
      integration = create(:integration)

      Spree.integrations << 'TestIntegrations::Registered'

      expect(integration.reload).to be_valid
    ensure
      Spree.integrations.delete('TestIntegrations::Registered')
    end
  end

  describe 'gallery metadata' do
    let(:described_klass) do
      Class.new(described_class) do
        def self.name = 'SpreeCarrier::Integration'
        def self.description = 'Fallback description'
      end
    end

    before { stub_const('SpreeCarrier::Integration', described_klass) }

    it 'declares no logo or description by default' do
      expect(described_class.logo_url).to be_nil
      expect(described_class.description).to be_nil
    end

    it 'falls back to the class description without a translation' do
      expect(SpreeCarrier::Integration.localized_description).to eq('Fallback description')
    end

    it 'prefers the Rails translation for the current locale' do
      translations = { spree: { integrations: { carrier: { description: 'Translated' } } } }
      I18n.backend.store_translations(:en, translations)

      expect(SpreeCarrier::Integration.localized_description).to eq('Translated')
    ensure
      I18n.backend.reload!
    end
  end

  describe 'verify before activate' do
    let(:failing_class) do
      Class.new(described_class) do
        def self.name = 'TestIntegrations::Failing'

        def can_connect?
          self.connection_error_message = 'bad credentials'
          false
        end
      end
    end

    before { stub_const('TestIntegrations::Failing', failing_class) }

    it 'saves failing credentials fine while inactive' do
      expect(TestIntegrations::Failing.new(store: @default_store, active: false)).to be_valid
    end

    it 'blocks activation with the connection error message' do
      integration = TestIntegrations::Failing.new(store: @default_store, active: true)

      expect(integration).not_to be_valid
      expect(integration.errors[:active]).to include('bad credentials')
    end

    it 'does not re-verify an already active integration on unrelated saves' do
      integration = create(:integration, active: true)

      expect(integration).not_to receive(:can_connect?)
      integration.update!(updated_at: Time.current)
    end
  end
end
