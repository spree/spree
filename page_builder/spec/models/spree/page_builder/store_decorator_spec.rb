require 'spec_helper'

RSpec.describe Spree::Store, type: :model do
  describe 'Callbacks' do
    describe '#create_default_theme' do
      let(:store) { build(:store) }

      it 'creates a default theme' do\
        expect(store.default_theme).to be_nil
        expect(store.themes.count).to eq(0)
        store.save!
        expect(store.themes.count).to eq(1)
        expect(store.reload.default_theme).to be_present
        expect(store.default_theme.name).to eq(Spree.t(:default_theme_name))
      end
    end

    describe '#create_default_policies' do
      let(:store) { build(:store) }

      it 'creates links for default policies' do
        expect(store.links.count).to eq(0)
        store.save!
        expect(store.links.count).to eq(4)
        expect(store.links.map(&:linkable)).to match_array(store.policies)
      end
    end
  end
end
