require 'spec_helper'

RSpec.describe Spree::Policy, type: :model do
  let(:store) { Spree::Store.default }
  let(:policy) { create(:policy, store: store) }

  describe 'validations' do
    context 'slug uniqueness' do
      before { policy }

      it 'allows same slug for different stores' do
        other_store = create(:store)
        other_policy = create(:policy, store: other_store, slug: policy.slug)
        expect(other_policy.slug).to eq(policy.slug)
      end
    end
  end

  describe 'friendly_id' do
    it 'generates friendly URLs from slug' do
      policy = create(:policy, slug: 'privacy-policy')
      expect(policy.to_param).to eq('privacy-policy')
    end

    it 'maintains slug history' do
      policy = create(:policy, slug: 'old-slug')
      policy.update(slug: 'new-slug')

      expect(policy.to_param).to eq('new-slug')
      expect(policy.friendly_id_config.uses?(:history)).to be true
    end
  end

  describe 'translations' do
    it 'has translatable name field' do
      expect(described_class::TRANSLATABLE_FIELDS).to include(:name)
    end

    it 'supports translations for name' do
      policy = create(:policy, name: 'Privacy Policy')

      I18n.with_locale(:es) do
        policy.name = 'Política de Privacidad'
        policy.body = 'Política de Privacidad'
        policy.save!
      end

      expect(policy.name).to eq('Privacy Policy')
      I18n.with_locale(:es) do
        expect(policy.name).to eq('Política de Privacidad')
        expect(policy.body.to_plain_text).to eq('Política de Privacidad')
      end
    end
  end

  describe 'scopes' do
    describe '.show_in_checkout_footer' do
      let!(:visible_policy) { create(:policy, show_in_checkout_footer: true) }
      let!(:hidden_policy) { create(:policy, show_in_checkout_footer: false) }

      it 'returns only policies that should be shown in checkout footer' do
        result = described_class.show_in_checkout_footer
        expect(result).to include(visible_policy)
        expect(result).not_to include(hidden_policy)
      end
    end

    describe '.for_store' do
      let(:other_store) { create(:store) }
      let!(:store1_policy) { create(:policy, store: store) }
      let!(:store2_policy) { create(:policy, store: other_store) }

      it 'returns policies for specific store' do
        result = described_class.for_store(store)
        expect(result).to include(store1_policy)
        expect(result).not_to include(store2_policy)
      end
    end
  end
end
