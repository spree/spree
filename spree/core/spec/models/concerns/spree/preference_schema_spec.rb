require 'spec_helper'

describe Spree::PreferenceSchema, type: :model do
  # Each STI parent declares where its registry lives via
  # `registers_subclasses_via`, which drives `find_by_api_type` and the
  # `subclasses_with_preference_schema` pickers.
  describe '.registered_subclasses' do
    it 'resolves a declared registry to its subclasses' do
      expect(Spree::DeliveryMethodRule.find_by_api_type('item_total_rule')).
        to eq(Spree::DeliveryMethodRules::ItemTotalRule)
      expect(Spree::PromotionRule.find_by_api_type('product')).to be_present
    end

    it 'resolves for every declared family, including gateways' do
      [Spree::PromotionAction, Spree::PriceRule, Spree::OrderRoutingRule,
       Spree::CollectionRule, Spree::PaymentMethod].each do |klass|
        expect { klass.subclasses_with_preference_schema }.not_to raise_error
      end
    end

    # `class_attribute` carries the parent's declaration down, so a lookup on a
    # concrete rule resolves the same registry as one on the STI parent.
    it 'resolves when called on an STI subclass' do
      expect(Spree::DeliveryMethodRules::ItemTotalRule.find_by_api_type('weight_rule')).
        to eq(Spree::DeliveryMethodRules::WeightRule)
    end

    # A missing declaration used to return an empty list, which silently
    # dropped typed rows from payloads and rendered empty admin pickers.
    it 'raises a rescuable error for a class that declares no registry' do
      expect(Spree::PreferenceSchema::UndeclaredRegistryError.ancestors).to include(StandardError)
      expect { Spree::Product.find_by_api_type('anything') }.
        to raise_error(Spree::PreferenceSchema::UndeclaredRegistryError, /no subclass registry/)
    end
  end
end
