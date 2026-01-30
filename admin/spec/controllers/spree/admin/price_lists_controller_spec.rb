require 'spec_helper'

RSpec.describe Spree::Admin::PriceListsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }

  describe 'GET #index' do
    subject(:index) { get :index }

    let!(:price_lists) { create_list(:price_list, 3, store: store) }

    it 'renders the list of price lists' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to contain_exactly(*price_lists)
    end
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: { id: price_list.to_param } }

    it 'renders the show page' do
      show

      expect(response).to render_template(:show)
    end

    context 'with price rules' do
      let!(:price_rule) { create(:volume_price_rule, price_list: price_list) }

      it 'displays the price rules' do
        show

        expect(response.body).to include(price_rule.class.human_name)
      end
    end
  end

  describe 'GET #edit_prices' do
    subject(:edit_prices) { get :edit_prices, params: { id: price_list.to_param, currency: currency } }

    let(:currency) { 'USD' }
    let(:product) { create(:product, stores: [store]) }
    let!(:variant) { product.master }
    let!(:price) { create(:price, variant: variant, price_list: price_list, currency: currency, amount: 10.0) }
    let!(:other_currency_price) { create(:price, variant: variant, price_list: price_list, currency: 'EUR', amount: 15.0) }

    it 'renders the edit prices page' do
      edit_prices

      expect(response).to render_template(:edit_prices)
    end

    it 'assigns prices for the specified currency' do
      edit_prices

      expect(assigns[:prices]).to include(price)
      expect(assigns[:prices]).not_to include(other_currency_price)
    end

    it 'assigns the currency' do
      edit_prices

      expect(assigns[:currency]).to eq(currency)
    end

    context 'without currency param' do
      subject(:edit_prices) { get :edit_prices, params: { id: price_list.to_param } }

      it 'uses the store default currency' do
        edit_prices

        expect(assigns[:currency]).to eq(store.default_currency)
      end
    end
  end

  describe 'PUT #update with nested prices_attributes' do
    subject(:update_price_list) { put :update, params: params }

    let(:product) { create(:product, stores: [store]) }
    let(:variant) { product.master }
    let!(:price) { create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: 10.0) }

    let(:params) do
      {
        id: price_list.to_param,
        price_list: {
          prices_attributes: {
            '0' => {
              id: price.id,
              variant_id: variant.id,
              currency: 'USD',
              amount: '25.99',
              compare_at_amount: '35.00'
            }
          }
        }
      }
    end

    it 'updates the price amount' do
      update_price_list
      price.reload

      expect(price.amount).to eq(25.99)
    end

    it 'updates the compare_at_amount' do
      update_price_list
      price.reload

      expect(price.compare_at_amount).to eq(35.00)
    end

    it 'enqueues a job to touch affected variants' do
      expect {
        update_price_list
      }.to have_enqueued_job(Spree::Variants::TouchJob).with([variant.id])
    end

    context 'when updating multiple prices' do
      let(:product2) { create(:product, stores: [store]) }
      let(:variant2) { product2.master }
      let!(:price2) { create(:price, variant: variant2, price_list: price_list, currency: 'USD', amount: 15.0) }

      let(:params) do
        {
          id: price_list.to_param,
          price_list: {
            prices_attributes: {
              '0' => { id: price.id, variant_id: variant.id, currency: 'USD', amount: '25.99' },
              '1' => { id: price2.id, variant_id: variant2.id, currency: 'USD', amount: '29.99' }
            }
          }
        }
      end

      it 'updates all prices' do
        update_price_list
        price.reload
        price2.reload

        expect(price.amount).to eq(25.99)
        expect(price2.amount).to eq(29.99)
      end
    end

    context 'when setting amount to blank on existing price' do
      let(:params) do
        {
          id: price_list.to_param,
          price_list: {
            prices_attributes: {
              '0' => { id: price.id, variant_id: variant.id, currency: 'USD', amount: '' }
            }
          }
        }
      end

      it 'keeps the price with nil amount' do
        update_price_list
        price.reload

        expect(price.amount).to be_nil
      end
    end
  end

  describe 'PUT #activate' do
    subject(:activate) { put :activate, params: { id: price_list.to_param } }

    context 'when price list has no starts_at' do
      let(:price_list) { create(:price_list, store: store, status: 'draft', starts_at: nil) }

      it 'activates the price list' do
        activate
        price_list.reload

        expect(price_list.status).to eq('active')
      end

      it 'redirects to show page with success message' do
        activate

        expect(response).to redirect_to(spree.admin_price_list_path(price_list))
        expect(flash[:success]).to eq(Spree.t('admin.price_lists.activated'))
      end
    end

    context 'when price list has starts_at' do
      let(:price_list) { create(:price_list, store: store, status: 'draft', starts_at: 1.day.from_now) }

      it 'schedules the price list' do
        activate
        price_list.reload

        expect(price_list.status).to eq('scheduled')
      end

      it 'redirects to show page with scheduled message' do
        activate

        expect(response).to redirect_to(spree.admin_price_list_path(price_list))
        expect(flash[:success]).to eq(Spree.t('admin.price_lists.scheduled'))
      end
    end

    context 'when price list is inactive' do
      let(:price_list) { create(:price_list, store: store, status: 'inactive', starts_at: nil) }

      it 'reactivates the price list' do
        activate
        price_list.reload

        expect(price_list.status).to eq('active')
      end
    end

    context 'when price list is inactive with starts_at' do
      let(:price_list) { create(:price_list, store: store, status: 'inactive', starts_at: 1.day.from_now) }

      it 'schedules the price list' do
        activate
        price_list.reload

        expect(price_list.status).to eq('scheduled')
      end
    end
  end

  describe 'PUT #deactivate' do
    subject(:deactivate) { put :deactivate, params: { id: price_list.to_param } }

    context 'when price list is active' do
      let(:price_list) { create(:price_list, store: store, status: 'active') }

      it 'deactivates the price list' do
        deactivate
        price_list.reload

        expect(price_list.status).to eq('inactive')
      end

      it 'redirects to show page with success message' do
        deactivate

        expect(response).to redirect_to(spree.admin_price_list_path(price_list))
        expect(flash[:success]).to eq(Spree.t('admin.price_lists.deactivated'))
      end
    end

    context 'when price list is scheduled' do
      let(:price_list) { create(:price_list, store: store, status: 'scheduled', starts_at: 1.day.from_now) }

      it 'deactivates the price list' do
        deactivate
        price_list.reload

        expect(price_list.status).to eq('inactive')
      end
    end
  end
end
