require 'spec_helper'

RSpec.describe Spree::Admin::StoresHelper, type: :helper do
  describe '#available_stores' do
    let(:user) { create(:admin_user) }
    let!(:store1) { create(:store, name: 'Store 1') }
    let!(:store2) { create(:store, name: 'Store 2') }
    let!(:store3) { create(:store, name: 'Store 3') }

    before do
      allow(helper).to receive(:current_ability).and_return(Spree::Ability.new(user))
    end

    context 'when user can manage all stores' do
      before do
        allow_any_instance_of(Spree::Ability).to receive(:can?).with(:manage, Spree::Store).and_return(true)
      end

      it 'returns all stores accessible by current ability' do
        expect(helper.available_stores).to include(store1, store2, store3)
      end
    end

    context 'when user has limited store access' do
      before do
        allow(Spree::Store).to receive(:accessible_by)
          .with(kind_of(Spree::Ability), :manage)
          .and_return(Spree::Store.where(id: [store1.id, store2.id]))
      end

      it 'returns only accessible stores' do
        available = helper.available_stores
        expect(available).to include(store1, store2)
        expect(available).not_to include(store3)
      end
    end
  end
end
