require 'spec_helper'

module Spree
  describe Spree::SingleStoreResource do
    let(:store) { Spree::Store.default }
    let(:store_2) { create :store }

    describe '.ensure_store_association_is_not_changed' do
      let(:menu) { create :menu }
      let(:menu_b) { create :menu, location: 'footer' }

      it 'allows creation of a new instance, update the store then save without triggering validation error' do
        object = Spree::CmsPage.new(title: 'Got Name', locale: 'de', type: 'Spree::Cms::Pages::StandardPage')
        object.update(store: store)

        expect(object.save!).to be true
      end

      context 'when an attempt to change the associated store' do
        it 'raises an ActiveRecord::RecordInvalid' do
          expect { menu.update!(store: store_2) }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context 'when update is made and store is same as existing store' do
        it 'does not raise an error' do
          expect { menu.update!(name:'Jones', store: store) }.not_to raise_error
        end
      end

      context 'when destroy a an item with store association' do
        it 'validation does not raise an error' do
          expect { menu_b.reload }.not_to raise_error

          menu_b.destroy

          expect { menu_b.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
