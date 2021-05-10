require 'spec_helper'

describe Spree::Menu, type: :model do
  it 'responds to for_header' do
    expect(described_class).to respond_to(:for_header)
  end

  it 'does not respond to for_some_other_location' do
    expect(described_class).not_to respond_to(:for_some_other_location)
  end

  describe 'creating new menu' do
    let(:store_1) { create(:store) }
    let(:store_2) { create(:store) }
    let(:store_3) { create(:store) }
    let!(:menu) { create(:menu, name: 'Footer Menu', location: 'Footer', store_id: store_1.id) }

    it 'validates presence of name' do
      expect(described_class.new(name: '', location: 'Header', store_id: store_3.id)).not_to be_valid
    end

    it 'validates presence of store' do
      expect(described_class.new(name: 'Got Name', location: 'Header', store_id: nil)).not_to be_valid
    end

    it 'validates presence of locale' do
      expect(described_class.new(name: 'No Locale For Me', location: 'Header', locale: nil, store_id: store_2.id)).not_to be_valid
    end

    it 'validates uniqueness of location within scope of language and store' do
      expect(described_class.new(name: 'BBB', location: 'Footer', locale: 'en', store_id: store_1.id)).not_to be_valid
      expect(described_class.new(name: 'BBB', location: 'Footer', locale: 'fr', store_id: store_1.id)).to be_valid
      expect(described_class.new(name: 'BBB', location: 'Header', locale: 'en', store_id: store_1.id)).to be_valid
      expect(described_class.new(name: 'BBB', location: 'Footer', locale: 'en', store_id: store_2.id)).to be_valid
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
    let(:m_x) { create(:menu, name: 'Main Menu', location: 'Header', store_id: store_a.id) }

    before do
      m_x.update!(name: 'Super Menu')
    end

    it '.update_root_name sets the new root menu_item name' do
      expect(m_x.root.name).to eql('Super Menu')
    end
  end
end
