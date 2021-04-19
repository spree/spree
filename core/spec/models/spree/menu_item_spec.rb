require 'spec_helper'

describe Spree::MenuItem, type: :model do
  describe 'validates name' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns presence error when no name is given' do
      expect(described_class.new(name: '', menu_id: menu.id, item_type: 'Link')).not_to be_valid
    end
  end

  describe 'validates menu_id presence and integer_only' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns error when no menu id is passed' do
      expect(described_class.new(name: 'Main Menu', item_type: 'Link')).not_to be_valid
    end

    it 'returns error when no menu id is not an integer' do
      expect(described_class.new(name: 'Main Menu', menu_id: 'string', item_type: 'Link')).not_to be_valid
    end

    it 'returns success when no menu id an integer' do
      expect(described_class.new(name: 'Main Menu', item_type: 'Link', menu_id: menu.id)).to be_valid
    end
  end

  describe 'validates item_type' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns error when the item_type is not in the list' do
      expect(described_class.new(name: 'Main Menu', menu_id: menu.id, item_type: 'Linkker')).not_to be_valid
    end
  end

  describe 'validates linked_resource_type' do
    let!(:menu) { create(:menu, name: 'Main Menu') }

    it 'returns error when the linked_resource_type is not in the list' do
      expect(described_class.new(name: 'Main Menu', menu_id: menu.id, item_type: 'Link', linked_resource_type: 'Purple')).not_to be_valid
    end
  end
end
