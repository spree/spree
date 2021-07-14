require 'spec_helper'

describe Spree::MenuLocation, type: :model do
  context 'creating a new location' do
    let!(:first_location) { create(:menu_location, name: 'First Location') }

    it 'validates presence of name' do
      expect(described_class.new(name: nil, parameterized_name: 'header')).not_to be_valid
    end

    it 'validates uniqueness of name' do
      expect(described_class.new(name: 'First Location')).not_to be_valid
    end

    describe '.parameterize_name' do
      let!(:new_location) { create(:menu_location, name: 'This Is My New Menu') }

      it 'takes the location name and parameterizes it' do
        expect(new_location.parameterized_name).to eql('this_is_my_new_menu')
      end
    end

    describe '.sync_menu' do
      let!(:store) { create(:store) }
      let(:menu) { build(:menu, store: store) }
      let!(:branding_bar_location) { create(:menu_location, name: 'Fancy Product Nav') }

      context 'when a new location is created' do
        it 'Spree::Menu#for_location responds to new location name' do
          expect(Spree::Menu).not_to respond_to(:none_existing_location)
          expect(Spree::Menu).to respond_to(:for_fancy_product_nav)
        end
      end
    end

    describe '.remove_location_from_menu' do
      let!(:new_branding_bar_location) { create(:menu_location, name: 'Out Of Date Nav') }

      context 'when a location is deleted' do
        before do
          new_branding_bar_location.destroy!
        end

        it 'Spree::Menu#for_location no longer responds to the deleted location' do
          expect(Spree::Menu).not_to respond_to(:for_out_of_date_nav)
        end
      end
    end
  end
end
