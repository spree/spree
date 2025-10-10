require 'spec_helper'

describe Spree::AddressesController, type: :controller do
  let(:store) { @default_store }
  let(:country) { store.default_country || create(:country_us) }
  let(:state) { create(:state, country: country, name: 'New York', abbr: 'NY') }
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
    subject(:post_create) { post :create, params: params }

    let(:params) { { address: address_params, default_billing: default_billing, default_shipping: default_shipping } }

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

      describe 'company field' do
        let(:company_name) { 'User Company Inc.' }
        let(:address_params) do
          address = build(:address, company: company_name, country: country, state: state)
          address.attributes.except('created_at', 'updated_at', 'quick_checkout')
        end

        before { store.update!(preferred_company_field_enabled: true) }
        after  { store.update!(preferred_company_field_enabled: false) }

        context 'when company field is provided' do
          it 'saves company field when creating address' do
            post_create

            expect(response.status).to eq(302)
            expect(user.addresses.last.company).to eq('User Company Inc.')
          end
        end

        context 'when company field is empty' do
          let(:company_name) { '' }

          it 'saves address without company field' do
            post_create

            expect(response.status).to eq(302)
            expect(user.addresses.last.company).to be_blank
          end
        end

        context 'when store has company field disabled' do
          before { store.update!(preferred_company_field_enabled: false) }

          it 'still saves company field if provided in params (backend compatibility)' do
            post_create

            expect(response.status).to eq(302)
            expect(user.addresses.last.company).to eq('User Company Inc.')
          end
        end
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

      context 'and new_address_modal frame request' do
        let(:params) { { address: address_params, default_billing: default_billing, default_shipping: default_shipping, from_modal: 'true' } }

        before { post_create }

        it 'responds with Turbo Stream and sets a unprocessable_entity status' do
          expect(response.status).to eq(422)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        end
      end
    end
  end

  describe '#update' do
    subject(:put_update) { put :update, params: params }

    let(:params) { { address: address_params, id: address.id } }

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

      describe 'company field handling' do
        let(:company_name) { 'Updated Company LLC' }
        let(:address_params) { address.attributes.symbolize_keys.merge(company: company_name) }

        before { store.update!(preferred_company_field_enabled: true) }
        after  { store.update!(preferred_company_field_enabled: false) }

        context 'when company field is provided' do
          it 'updates company field' do
            put_update

            expect(response.status).to eq(302)
            expect(address.reload.company).to eq('Updated Company LLC')
          end
        end

        context 'when company field is empty' do
          let(:company_name) { '' }

          it 'updates address with blank company field' do
            put_update

            expect(response.status).to eq(302)
            expect(address.reload.company).to be_blank
          end
        end

        context 'when store has company field disabled' do
          before { store.update!(preferred_company_field_enabled: false) }

          it 'still updates company field if provided in params (backend compatibility)' do
            put_update

            expect(response.status).to eq(302)
            expect(address.reload.company).to eq('Updated Company LLC')
          end
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

        context 'and edit_address_modal frame request' do
          let(:params) { { address: address_params, id: address.id, from_modal: 'true' } }

          before { put_update }

          it 'responds with Turbo Stream and sets a unprocessable_entity status' do
            expect(response.status).to eq(422)
            expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          end
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
