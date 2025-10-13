require 'spec_helper'

RSpec.describe Spree::Policy, type: :model do
  let(:store) { Spree::Store.default }
  let(:policy) { create(:policy, owner: store) }

  describe 'Validations' do
    context 'slug uniqueness' do
      before { policy }

      it 'allows same slug for different stores' do
        other_store = create(:store)
        other_policy = create(:policy, owner: other_store, slug: policy.slug)
        expect(other_policy.slug).to eq(policy.slug)
      end
    end

    context 'owner presence' do
      it 'is invalid without an owner' do
        policy.owner = nil
        expect(policy).to be_invalid
      end
    end
  end

  describe 'Callbacks' do
    context 'after destroy destroys links in which policy is linked to' do
      let!(:page_link) { create(:page_link, linkable: policy, parent: store) }

      it 'destroys links' do
        expect(store.links).to include(page_link)
        expect { policy.destroy }.to change(Spree::PageLink, :count).by(-1)
        expect(store.links).not_to include(page_link)
      end
    end
  end

  describe 'friendly_id' do
    it 'generates friendly URLs from slug' do
      policy = create(:policy, slug: 'my-policy')
      expect(policy.to_param).to eq('my-policy')
    end

    it 'maintains slug history' do
      policy = create(:policy, slug: 'old-slug')
      policy.update(slug: 'new-slug')

      expect(policy.to_param).to eq('new-slug')
      expect(policy.friendly_id_config.uses?(:history)).to be true
    end

    context 'when the policy is destroyed' do
      it 'fully destroys the slug' do
        policy = create(:policy, name: 'Test policy 123', slug: 'test-policy-123')
        expect(policy.slugs.count).to eq(1)

        policy.destroy

        expect(FriendlyId::Slug.with_deleted.find_by(slug: 'test-policy-123')).to be_blank
      end
    end
  end

  describe 'Translations' do
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

  describe 'Scopes' do
    describe '.for_store' do
      let(:other_store) { create(:store) }
      let!(:store1_policy) { create(:policy, owner: store) }
      let!(:store2_policy) { create(:policy, owner: other_store) }

      it 'returns policies for specific store' do
        result = described_class.for_store(store)
        expect(result).to include(store1_policy)
        expect(result).not_to include(store2_policy)
      end
    end
  end
end
