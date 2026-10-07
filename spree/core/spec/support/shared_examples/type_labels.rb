# Shared behavior for families that include Spree::TypeLabels.
RSpec.shared_examples 'type labels' do
  describe 'type labels' do
    let(:kind) { stub_const('MyApp::LoyaltyTierKind', Class.new(described_class.base_class)) }

    it "reads the kind's name and description from the family's scope" do
      labels = { loyalty_tier_kind: { name: 'Loyalty tier', description: 'Members of a tier' } }
      I18n.backend.store_translations(:en, kind.type_labels_scope.split('.').reverse.reduce(labels) { |tree, key| { key => tree } })

      expect(kind.human_name).to eq('Loyalty tier')
      expect(kind.human_description).to eq('Members of a tier')
      expect(kind.new.human_name).to eq('Loyalty tier')
    end

    it 'falls back to the humanized type for a kind without translations' do
      untranslated = stub_const('MyApp::UntranslatedKind', Class.new(described_class.base_class))

      expect(untranslated.human_name).to eq('Untranslated Kind')
      expect(untranslated.human_description).to eq('')
    end
  end
end
