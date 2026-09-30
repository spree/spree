require 'spec_helper'
require 'open3'
require_relative '../../../fixtures/registry_boot/registries'

RSpec.describe Spree::Core::Engine do
  describe "'spree.returns.register_eligibility_validator' initializer" do
    let(:initializer) { described_class.instance.initializers.find { |i| i.name == 'spree.returns.register_eligibility_validator' } }
    let(:boot_order) { Rails.application.initializers.tsort_each.to_a }

    before do
      Spree.hooks.unregister('returns.create.validate', 'Spree::Returns::EligibilityValidator')
      Spree.hooks.unregister('exchanges.create.validate', 'Spree::Returns::EligibilityValidator')
    end

    after { initializer.run(Rails.application) }

    # A store swaps the default rule by unregistering it in its own
    # config/initializers file, which only sticks if core registered first.
    it 'runs before the application loads its config/initializers' do
      application_initializers = boot_order.index do |i|
        i.name == :load_config_initializers && i.context_class == Rails.application.class
      end

      expect(boot_order.index { |i| i.name == initializer.name }).to be < application_initializers
    end

    it 'registers the validator on the returns and exchanges create hooks, without duplicating it when run again' do
      2.times { initializer.run(Rails.application) }

      expect(Spree.hooks.for('returns.create.validate').map(&:class)).to eq([Spree::Returns::EligibilityValidator])
      expect(Spree.hooks.for('exchanges.create.validate').map(&:class)).to eq([Spree::Returns::EligibilityValidator])
    end
  end

  # Boots the dummy application in a separate process with a probe registered
  # from an extension engine's initializer, an application initializer file and
  # an after_initialize block — see spec/fixtures/registry_boot.
  describe 'registries at boot' do
    let(:probes) { %w[ExtensionProbe ApplicationProbe AfterInitializeProbe] }

    before(:context) do
      output, errors, status = Open3.capture3(RbConfig.ruby, File.expand_path('../../../fixtures/registry_boot/boot.rb', __dir__), Rails.root.to_s)
      raise "Dummy application failed to boot:\n#{errors}" unless status.success?

      @registries = JSON.parse(output.lines.last)
    end

    RegistryBoot::ARRAY_REGISTRIES.each do |path|
      it "keeps what initializers added to config.spree.#{path}, after core's defaults and once each" do
        defaults = RegistryBoot.names(RegistryBoot.registry(path))

        expect(@registries.fetch(path).first(defaults.size)).to eq(defaults)
        expect(@registries.fetch(path).drop(defaults.size)).to contain_exactly(*probes)
      end
    end

    it 'keeps carriers and analytics events added from an initializer, letting it override a default' do
      expect(@registries['tracking_carriers']).to eq(Spree.tracking_carriers.keys + ['probe'])
      expect(@registries['tracking_carriers.ups']).to eq('Custom UPS')
      expect(@registries['analytics.events']).to eq(Spree.analytics.events.keys.map(&:to_s) + ['probe_viewed'])
    end

    it 'keeps single-value settings assigned from an initializer' do
      expect(@registries.values_at('password_validator', 'default_tax_provider', 'default_payout_provider')).to all(eq('ApplicationProbe'))
    end

    it 'keeps address validators registered from an initializer and unregistered in to_prepare' do
      expect(@registries['validators.addresses']).to eq(['ApplicationProbe'])
    end

    it 'keeps authentication strategies added, replaced and removed from an initializer' do
      expect(@registries['store_authentication_strategies']).to eq(%w[email probe])
      expect(@registries['admin_authentication_strategies.email']).to eq('ApplicationProbe')
      expect(@registries['seller_authentication_strategies']).to be_empty
    end
  end
end
