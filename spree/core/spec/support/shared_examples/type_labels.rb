# Shared behavior for families that include Spree::TypeLabels. Pass a built-in
# kind of the family that has a translation.
RSpec.shared_examples 'type labels' do |kind|
  describe 'type labels' do
    it "reads the kind's name and description from the family's scope" do
      expect(kind.human_name).to eq(I18n.t("#{kind.type_labels_scope}.#{kind.api_type}.name"))
      expect(kind.human_description).to eq(I18n.t("#{kind.type_labels_scope}.#{kind.api_type}.description"))
    end

    it 'answers on an instance too' do
      expect(kind.new.human_name).to eq(kind.human_name)
    end

    it 'falls back to the humanized type for a kind without translations' do
      extension = stub_const('MyApp::LoyaltyTierKind', Class.new(kind.base_class))

      expect(extension.human_name).to eq('Loyalty Tier Kind')
      expect(extension.human_description).to eq('')
    end
  end
end
