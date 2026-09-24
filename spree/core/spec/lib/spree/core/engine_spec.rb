require 'spec_helper'

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
end
