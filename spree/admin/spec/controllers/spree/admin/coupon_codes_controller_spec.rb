require 'spec_helper'

RSpec.describe Spree::Admin::CouponCodesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:promotion) { create(:promotion, stores: [store]) }

  describe '#index' do
    let!(:coupon_code) { create(:coupon_code, promotion: promotion) }

    subject { get :index, params: { promotion_id: promotion.to_param } }

    it 'renders the index template' do
      subject
      expect(response).to render_template(:index)
      expect(response).to have_http_status(:ok)
    end

    it 'assigns the collection scoped to the promotion' do
      other_promotion = create(:promotion, stores: [store])
      other_coupon_code = create(:coupon_code, promotion: other_promotion)

      subject

      expect(assigns(:collection)).to include(coupon_code)
      expect(assigns(:collection)).not_to include(other_coupon_code)
    end

    it 'injects promotion_id_eq into ransack params' do
      subject
      expect(controller.params[:q][:promotion_id_eq]).to eq(promotion.id)
    end

    context 'with code search' do
      let!(:matching_coupon) { create(:coupon_code, code: 'summer20', promotion: promotion) }
      let!(:other_coupon) { create(:coupon_code, code: 'winter10', promotion: promotion) }

      it 'filters by code' do
        get :index, params: { promotion_id: promotion.to_param, q: { code_i_cont: 'summer' } }

        expect(assigns(:collection)).to include(matching_coupon)
        expect(assigns(:collection)).not_to include(other_coupon)
      end
    end
  end
end
