require 'spec_helper'

describe Spree::Menu, type: :model do
  it 'responds to for_header' do
    expect(described_class).to respond_to(:for_header)
  end

  it 'does not respond to for_some_other_location' do
    expect(described_class).not_to respond_to(:for_some_other_location)
  end

  describe 'by_store' do
    let!(:store) { create(:store) }
    let!(:store_b) { create(:store) }

    let!(:menu_a) { create(:menu, store: store) }
    let!(:menu_b) { create(:menu, store: store_b) }

    it 'returns menus for the requested store' do
      expect(described_class.by_store(store)).to eq([menu_a])
    end
  end

  describe 'by_locale' do
    let!(:store_milti) { create(:store) }
    let!(:menu_en) { create(:menu, store: store_milti, locale: 'en') }
    let!(:menu_fr) { create(:menu, store: store_milti, locale: 'fr') }

    it 'returns menus for the requested locale' do
      expect(described_class.by_locale('fr')).to eq([menu_fr])
    end
  end

  describe 'creating new menu' do
    let(:store_1) { create(:store) }
    let(:store_2) { create(:store) }
    let(:store_3) { create(:store) }
    let!(:menu) { create(:menu, name: 'Footer Menu', location: 'Footer', store: store_1) }

    it 'validates presence of name' do
      expect(described_class.new(name: '', location: 'Header', store: store_3)).not_to be_valid
    end

    it 'validates presence of store' do
      expect(described_class.new(name: 'Got Name', location: 'Header', store_id: nil)).not_to be_valid
    end

    it 'validates presence of locale' do
      expect(described_class.new(name: 'No Locale For Me', location: 'Header', locale: nil, store: store_2)).not_to be_valid
    end

    it 'validates uniqueness of location within scope of language and store' do
      expect(described_class.new(name: 'BBB', location: 'Footer', locale: 'en', store: store_1)).not_to be_valid
      expect(described_class.new(name: 'BBB', location: 'Footer', locale: 'fr', store: store_1)).to be_valid
      expect(described_class.new(name: 'BBB', location: 'Header', locale: 'en', store: store_1)).to be_valid
      expect(described_class.new(name: 'BBB', location: 'Footer', locale: 'en', store: store_2)).to be_valid
    end

    it '.paremeterize_location parametizes the location' do
      expect(menu.location).to eql('footer')
    end

    it '.set_root creates a new root item' do
      expect(menu.root.name).to eql('Footer Menu')
      expect(menu.root.root?).to be true
      expect(menu.root.item_type).to eql('Container')
    end
  end

  describe 'updating the menu name' do
    let(:store_a) { create(:store) }
    let(:m_x) { create(:menu, name: 'Main Menu', location: 'Header', store: store_a) }

    before do
      m_x.update!(name: 'Super Menu')
    end

    it '.update_root_name sets the new root menu_item name' do
      expect(m_x.root.name).to eql('Super Menu')
    end
  end

  describe 'touch store' do
    let!(:store) { create(:store) }
    let(:menu) { build(:menu, store: store) }

    it { expect { menu.save! }.to change(store, :updated_at) }
  end
end
