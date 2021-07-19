require 'spec_helper'

module Spree
  module Admin
    describe StoreCreditsController, type: :controller do
      stub_authorization!

      let(:store) { Spree::Store.default }
      let(:user) { create(:user) }

      describe '#index' do
        let!(:store_credit_1) { create(:store_credit, user: user, store: store) }
        let!(:store_credit_2) { create(:store_credit, user: user, amount_used: 10, store: store) }
        let!(:store_credit_3) { create(:store_credit, user: user) }
        let!(:store_credit_4) { create(:store_credit, store: store, user: create(:user)) }

        it 'should assign only the store credits for user and current store' do
          get :index, params: { user_id: user.id }
          expect(assigns(:store_credits)).to include store_credit_1
          expect(assigns(:store_credits)).to include store_credit_2
          expect(assigns(:store_credits)).not_to include store_credit_3
          expect(assigns(:store_credits)).not_to include store_credit_4
        end
      end

      describe '#destroy' do
        subject(:send_request) do
          delete :destroy, params: { user_id: user.id, id: store_credit_to_destroy.id, format: :js }
        end

        context 'will successfully destroy store credit' do
          let(:store_credit_to_destroy) { create(:store_credit, user: user, store: store) }

          describe 'returns response' do
            before { send_request }

            it { expect(assigns(:store_credit)).to eq(store_credit_to_destroy) }
            it { expect(response).to have_http_status(:ok) }
            it { expect(flash[:success]).to eq(Spree.t('successfully_removed', resource: 'Store Credit')) }
          end
        end

        context 'cannot destroy store credit of other user' do
          let(:store_credit_to_destroy) { create(:store_credit) }

          it { expect { send_request }.to raise_error(ActiveRecord::RecordNotFound) }
        end

        context 'cannot destroy store credit from another store' do
          let(:store_credit_to_destroy) { create(:store_credit, user: user, store:create(:store)) }

          it { expect { send_request }.to raise_error(ActiveRecord::RecordNotFound) }
        end

        context 'cannot destroy store credit with used amount' do
          let(:store_credit_to_destroy) { create(:store_credit, store: store, user: user, amount_used: 10) }

          it { expect { send_request }.to raise_error(Spree::Admin::StoreCreditError) }
        end
      end
    end
  end
end
