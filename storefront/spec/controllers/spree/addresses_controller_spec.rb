require 'spec_helper'

describe Spree::AddressesController, type: :controller do
  let(:store) { Spree::Store.default }
  let(:country) { store.default_country }
  let(:state) { create(:state, country: country) }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_totals, store: store) }
  let(:default_billing) { 'true' }
  let(:default_shipping) { 'true' }

  render_views

  before do
    allow(controller).to receive_messages try_spree_current_user: user
    allow(controller).to receive_messages spree_current_user: user
    allow(controller).to receive_messages current_order: order
    allow_any_instance_of(CanCan::ControllerResource).to receive(:load_resource)
    allow_any_instance_of(CanCan::ControllerResource).to receive(:authorize_resource)
  end

  describe '#create' do
    subject :post_create do
      post :create, params: { address: address_params, default_billing: default_billing, default_shipping: default_shipping }
    end

    context 'when data is valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state)
        address.attributes.except('created_at', 'updated_at', 'quick_checkout')
      end

      it 'returns 302 status code' do
        post_create

        expect(response.status).to eq(302)
      end

      it 'redirects to /account/addresses' do
        post_create

        expect(response).to redirect_to('/account/addresses')
      end

      it 'creates address' do
        expect { post_create }.to change { user.addresses.count }.by(1)
      end

      it 'sets flash message' do
        post_create

        expect(flash[:notice]).to eq Spree.t('address_book.successfully_created')
      end

      context 'default address' do
        let!(:default_address) { create(:address, user: user) }

        before { user.update!(ship_address: default_address, bill_address: default_address) }

        context 'when default_shipping param is false' do
          let(:default_shipping) { nil }

          it 'does not set default shipping address' do
            post_create

            expect(user.reload.shipping_address).to eq(default_address)
            expect(user.billing_address).to eq(Spree::Address.last)
          end
        end

        context 'when default_billing param is false' do
          let(:default_billing) { nil }

          it 'does not set default billing address' do
            post_create

            expect(user.reload.billing_address).to eq(default_address)
            expect(user.shipping_address).to eq(Spree::Address.last)
          end
        end
      end
    end

    context 'when data is not valid' do
      let(:address_params) do
        address = build(:address, country: country, state: state, first_name: nil)
        address.attributes.except('created_at', 'updated_at')
      end

      it 'does not create address' do
        expect { post_create }.not_to change { user.addresses.count }
      end

      it 'returns 422 status code' do
        post_create

        expect(response.status).to eq(422)
      end

      it 'renders address form template' do
        expect(post_create).to render_template(:new)
      end
    end
  end

  describe '#update' do
    subject :put_update do
      put :update, params: { address: address_params, id: address.id }
    end

    before { controller.instance_variable_set(:@address, address) }

    context 'when address is editable' do
      let(:address) { create(:address, country: country, state: state, label: 'label', user: user) }

      context 'with data is valid' do
        let(:address_params) { address.attributes.symbolize_keys.merge(firstname: 'Test') }

        it 'updates address' do
          expect(address.attributes.symbolize_keys.except(:created_at, :updated_at)).not_to match(address_params.except(:created_at, :updated_at))

          put_update

          expect(address.firstname).to eq 'Test'
        end

        it 'sets flash message' do
          put_update

          expect(flash[:notice]).to eq Spree.t('address_book.successfully_updated')
        end

        it 'returns 302 status code' do
          put_update

          expect(response.status).to eq(302)
        end

        it 'redirects to /account/addresses' do
          put_update

          expect(response).to redirect_to(spree.account_addresses_path)
        end
      end

      context 'when data is not valid' do
        let(:address_params) { address.attributes.symbolize_keys.merge(firstname: nil) }

        it 'does not update address' do
          expect { put_update }.not_to change { address }
        end

        it 'renders address form template' do
          expect(put_update).to render_template(:edit)
        end
      end
    end

    context 'when address is not editable' do
      let(:address) { create(:address, country: country, state: state, label: 'label', user: user) }
      let!(:order) { create(:completed_order_with_totals, ship_address: address) }

      context 'with data is valid' do
        let(:address_params) { address.attributes.symbolize_keys.except(:id, :quick_checkout).merge(firstname: 'test', label: '') }

        it 'creates address' do
          expect { put_update }.to change { Spree::Address.count }.by(1)
        end

        it 'sets deleted_at attribute of original address' do
          Timecop.freeze(Time.current) do
            expect(address.deleted_at).to be_nil

            put_update

            expect(address.deleted_at).not_to be nil
          end
        end

        it 'sets flash message' do
          put_update

          expect(flash[:notice]).to eq Spree.t('address_book.successfully_updated')
        end

        it 'returns 302 status code' do
          put_update

          expect(response.status).to eq(302)
        end

        it 'redirects to /account/addresses' do
          put_update

          expect(response).to redirect_to(spree.account_addresses_path)
        end
      end

      context 'when data is not valid' do
        let(:address_params) { address.attributes.symbolize_keys.except(:skip_mainstreet_validation, :quick_checkout).merge(address1: nil) }

        it 'does not create address' do
          expect { put_update }.to change { Spree::Address.count }.by(0)
        end

        it 'renders address form template' do
          expect(put_update).to render_template(:edit)
        end
      end
    end
  end
end
