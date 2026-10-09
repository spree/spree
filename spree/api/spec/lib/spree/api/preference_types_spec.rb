require 'spec_helper'
require Spree::Api::Engine.root.join('lib/spree/api/preference_types').to_s

RSpec.describe Spree::Api::PreferenceTypes do
  subject(:generator) { described_class.new }

  let(:monorepo_root) { Spree::Api::Engine.root.join('../..') }

  it 'matches the committed SDK files (run `bundle exec rake typelizer:generate` to refresh them)' do
    generator.render.each do |path, source|
      expect(monorepo_root.join(path).read).to eq(source), "#{path} is out of date with the preference declarations"
    end
  end

  it 'types each subtype of a family and keys the map by its wire type' do
    source = generator.render.fetch('packages/admin-sdk/src/types/preferences.ts')

    expect(source).to include(
      "export interface PromotionRuleItemTotalPreferences {\n  /** An amount, as an exact decimal string. */\n  amount_min: string\n"
    )
    expect(source).to include("  item_total: PromotionRuleItemTotalPreferences\n")
    expect(source).to include("  match_policy: 'any' | 'all' | 'none'\n")
    expect(source).to include("export type TypedPromotionRule = Narrowed<PromotionRule, PromotionRulePreferencesMap>\n")
  end

  it 'gives the seller panel only the families a seller writes' do
    source = generator.render.fetch('packages/seller-sdk/src/types/preferences.ts')

    expect(source).to include('export interface DeliveryMethodRulePreferencesMap')
    expect(source).not_to include('PromotionRule')
  end
end
