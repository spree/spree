require 'spec_helper'
describe 'StoreCreditCategory' do
  describe 'callbacks' do
    context 'store credit category is not used in store credit' do
      let!(:store_credit_category) { create(:store_credit_category) }

      it 'can delete store credit category' do
        expect { store_credit_category.destroy }.to change(Spree::StoreCreditCategory, :count).by(-1)
      end
    end

    context 'store credit category is used in store credit' do
      let!(:store_credit_category) { create(:store_credit_category) }
      let!(:store_credit) { create(:store_credit, category_id: store_credit_category.id) }

      it 'can not delete store credit category' do
        store_credit_category.destroy
        expect(store_credit_category.errors[:base]).to include(
          I18n.t('activerecord.errors.models.spree/store_credit_category.attributes.base.cannot_destroy_if_used_in_store_credit')
        )
      end
    end
  end
end
