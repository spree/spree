require 'spec_helper'

describe Spree::Admin::PromotionsController, type: :controller do
  stub_authorization!

  let!(:promotion1) { create(:promotion, name: 'name1', code: 'code1', path: 'path1') }
  let!(:promotion2) { create(:promotion, name: 'name2', code: 'code2', path: 'path2') }
  let!(:category) { create :promotion_category }

  context '#index' do
    it 'succeeds' do
      get :index
      expect(assigns[:promotions]).to match_array [promotion2, promotion1]
    end

    it 'assigns promotion categories' do
      get :index
      expect(assigns[:promotion_categories]).to match_array [category]
    end

    context 'search' do
      it 'pages results' do
        get :index, params: { per_page: '1' }
        expect(assigns[:promotions]).to eq [promotion2]
      end

      it 'filters by name' do
        get :index, params: { q: { name_cont: promotion1.name } }
        expect(assigns[:promotions]).to eq [promotion1]
      end

      it 'filters by code' do
        get :index, params: { q: { code_cont: promotion1.code } }
        expect(assigns[:promotions]).to eq [promotion1]
      end

      it 'filters by path' do
        get :index, params: { q: { path_cont: promotion1.path } }
        expect(assigns[:promotions]).to eq [promotion1]
      end
    end
  end

  context '#clone' do
    context 'cloning valid promotion' do
      subject do
        post :clone, params: { id: promotion1.id }
      end

      it 'creates a copy of promotion' do
        expect { subject }.to change { Spree::Promotion.count }.by(1)
      end

      it 'creates a copy of promotion with changed fields' do
        subject
        new_promo = Spree::Promotion.last
        expect(new_promo.name).to eq 'New name1'
        expect(new_promo.code).to eq 'code1_new'
        expect(new_promo.path).to eq 'path1_new'
      end
    end

    context 'cloning invalid promotion' do
      subject do
        post :clone, params: { id: promotion3.id }
      end

      let!(:promotion3) { create(:promotion, name: 'Name3', code: 'code3', path: '') }

      before do
        create(:promotion, name: 'Name4', code: 'code4', path: '_new') # promotion 4
      end

      it 'doesnt create a copy of promotion' do
        expect { subject }.not_to(change { Spree::Promotion.count })
      end

      it 'returns error' do
        subject
        expected_error = Spree.t('promotion_not_cloned', error: assigns(:new_promo).errors.full_messages.to_sentence)
        expect(flash[:error]).to eq(expected_error)
      end
    end
  end
end
