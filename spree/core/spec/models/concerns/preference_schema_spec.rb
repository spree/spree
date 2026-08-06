require 'spec_helper'

describe Spree::PreferenceSchema, type: :model do
  # Each STI parent declares where its registry lives via
  # `registers_subclasses_via`, which drives `find_by_api_type` and the
  # `subclasses_with_preference_schema` pickers.
  describe '.registered_subclasses' do
    it 'resolves the declared registry for every rule family' do
      expect(Spree::DeliveryMethodRule.find_by_api_type('item_total_rule')).
        to eq(Spree::DeliveryMethodRules::ItemTotalRule)
      expect(Spree::PromotionRule.find_by_api_type('product')).to be_present
      expect(Spree::PromotionAction.subclasses_with_preference_schema).to be_an(Array)
      expect(Spree::PriceRule.subclasses_with_preference_schema).to be_an(Array)
      expect(Spree::OrderRoutingRule.subclasses_with_preference_schema).to be_an(Array)
      expect(Spree::CollectionRule.subclasses_with_preference_schema).to be_an(Array)
    end

    # Class-level ivars are not inherited, so the lookup walks up to the
    # declaring ancestor.
    it 'resolves when called on an STI subclass' do
      expect(Spree::DeliveryMethodRules::ItemTotalRule.find_by_api_type('weight_rule')).
        to eq(Spree::DeliveryMethodRules::WeightRule)
    end

    it 'still routes gateways through their providers registry' do
      expect(Spree::PaymentMethod.subclasses_with_preference_schema).to be_an(Array)
    end

    # A missing declaration used to return an empty list, which silently
    # dropped typed rows from payloads and rendered empty admin pickers.
    it 'raises for a class that declares no registry' do
      expect { Spree::Product.find_by_api_type('anything') }.
        to raise_error(NotImplementedError, /declares no subclass registry/)
    end
  end
end
