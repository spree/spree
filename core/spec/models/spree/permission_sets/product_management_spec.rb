require 'spec_helper'
require 'cancan/matchers'

RSpec.describe Spree::PermissionSets::ProductManagement do
  let(:user) { build(:user) }
  let(:ability) { Spree::Ability.new(user) }

  subject(:permission_set) { described_class.new(ability) }

  before { permission_set.activate! }

  describe '#activate!' do
    it 'grants manage access to Product' do
      expect(ability.can?(:manage, Spree::Product)).to be true
    end

    it 'grants manage access to Variant' do
      expect(ability.can?(:manage, Spree::Variant)).to be true
    end

    it 'grants manage access to OptionType' do
      expect(ability.can?(:manage, Spree::OptionType)).to be true
    end

    it 'grants manage access to OptionValue' do
      expect(ability.can?(:manage, Spree::OptionValue)).to be true
    end

    it 'grants manage access to Property' do
      expect(ability.can?(:manage, Spree::Property)).to be true
    end

    it 'grants manage access to ProductProperty' do
      expect(ability.can?(:manage, Spree::ProductProperty)).to be true
    end

    it 'grants manage access to Taxon' do
      expect(ability.can?(:manage, Spree::Taxon)).to be true
    end

    it 'grants manage access to Taxonomy' do
      expect(ability.can?(:manage, Spree::Taxonomy)).to be true
    end

    it 'grants manage access to Classification' do
      expect(ability.can?(:manage, Spree::Classification)).to be true
    end

    it 'grants manage access to Price' do
      expect(ability.can?(:manage, Spree::Price)).to be true
    end

    it 'does not grant manage access to Order' do
      expect(ability.can?(:manage, Spree::Order)).to be false
    end

    it 'does not grant manage access to User' do
      expect(ability.can?(:manage, Spree.user_class)).to be false
    end
  end
end
