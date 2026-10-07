require 'spec_helper'

RSpec.describe Spree::TypeLabels do
  let(:rule_class) { Spree::Promotion::Rules::Category }

  it "reads the kind's name and description from its family's scope" do
    expect(rule_class.human_name).to eq('Categories')
    expect(rule_class.human_description).to eq('Order includes products in specified categories')
  end

  it 'answers on an instance too' do
    expect(rule_class.new.human_name).to eq('Categories')
  end

  context 'for a kind without translations' do
    let(:rule_class) { stub_const('MyApp::LoyaltyTierRule', Class.new(Spree::PromotionRule)) }

    it 'falls back to its humanized type and an empty description' do
      expect(rule_class.human_name).to eq('Loyalty Tier Rule')
      expect(rule_class.human_description).to eq('')
    end
  end
end
