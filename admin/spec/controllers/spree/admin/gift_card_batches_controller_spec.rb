require 'spec_helper'

describe Spree::Admin::GiftCardBatchesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe '#new' do
    subject { get :new }

    it 'renders the new template' do
      subject
      expect(response).to render_template(:new)
      expect(response).to have_http_status(:ok)
    end

    it 'assigns a new gift card batch' do
      subject
      expect(assigns(:object)).to be_a_new(Spree::GiftCardBatch)
    end
  end

  describe '#create' do
    let(:valid_params) do
      {
        gift_card_batch: {
          prefix: 'BATCH001',
          amount: 10,
          currency: 'EUR',
          codes_count: 20,
          expires_at: 1.year.from_now.to_date
        }
      }
    end

    subject { post :create, params: valid_params }

    context 'with valid parameters' do
      it 'creates a new gift card batch' do
        expect { subject }.to change(Spree::GiftCardBatch, :count).by(1)

        gift_card_batch = Spree::GiftCardBatch.last
        expect(gift_card_batch.prefix).to eq('BATCH001')
        expect(gift_card_batch.amount).to eq(10)
        expect(gift_card_batch.currency).to eq('EUR')
        expect(gift_card_batch.codes_count).to eq(20)
        expect(gift_card_batch.expires_at).to eq(1.year.from_now.to_date)
        expect(gift_card_batch.store).to eq(store)

        expect(gift_card_batch.gift_cards.count).to eq(20)
      end

      it 'redirects to the gift cards index with batch filter' do
        subject
        expect(response).to redirect_to(spree.admin_gift_cards_path(q: { batch_prefix_eq: 'BATCH001' }))
      end

      it 'sets a success flash message' do
        subject
        expect(flash[:success]).to be_present
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          gift_card_batch: {
            amount: -100,
            currency: 'EUR'
          }
        }
      end

      subject { post :create, params: invalid_params }

      it 'does not create a gift card batch' do
        expect { subject }.not_to change(Spree::GiftCardBatch, :count)
      end

      it 'renders the new template' do
        subject
        expect(response).to render_template(:new)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
