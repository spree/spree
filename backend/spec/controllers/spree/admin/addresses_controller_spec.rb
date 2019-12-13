require 'spec_helper'

module Spree
  module Admin
    describe AddressesController, type: :controller do
      stub_authorization!

      describe '#update' do
        let(:admin_user) { create(:admin_user) }

        context 'when address editable' do
          let!(:address) { create(:address, firstname: 'Henry', user: admin_user) }

          context 'with valid params' do
            let(:subject)  { put :update, params: { id: address.id, address: { firstname: 'John' }}}

            it 'updates address' do
              subject
              address.reload
              expect(address.firstname).to eq 'John'
            end

            it 'redirects to user addresses path' do
              expect(subject).to redirect_to addresses_admin_user_path(admin_user)
            end

            it 'renders success flash message' do
              expect(subject.request.flash[:success]).to eq Spree.t(:successfully_updated, resource: Spree.t(:address))
            end
          end

          context 'with invalid params' do
            let(:subject) { put :update, params: { id: address.id, address: { firstname: '' }}}

            it 'renders edit' do
              expect(subject).to render_template(:edit)
            end

            it 'does not change address' do
              subject
              expect(address.reload.firstname).to eq 'Henry'
            end
          end
        end

        context 'when address not editable' do
          let!(:address_with_shipment) { create(:address, firstname: 'Henry', user: admin_user) }
          let!(:shipment)              { create(:shipment, address: address_with_shipment) }

          context 'with valid params' do
            let(:subject) { put :update, params: { id: address_with_shipment.id, address: { firstname: 'John' }}}
            
            it 'deletes exisitng address and creates a new one' do
              expect { subject }.to change(Spree::Address, :count).by(1)
              expect(address_with_shipment.reload.deleted_at).not_to be nil
              expect(Spree::Address.last.id).to_not eq(address_with_shipment.id)
            end

            it 'updates new address' do
              subject
              expect(Spree::Address.last.firstname).to eq 'John'
            end

            it 'redirects to user addresses path' do
              expect(subject).to redirect_to addresses_admin_user_path(admin_user)
            end

            it 'renders success flash message' do
              expect(subject.request.flash[:success]).to eq Spree.t(:successfully_updated, resource: Spree.t(:address))
            end
          end

          context 'with invalid params' do
            let(:subject) { put :update, params: { id: address_with_shipment.id, address: { firstname: '' }}}

            it 'renders edit' do
              expect(subject).to render_template(:edit)
            end

            it 'does not change address' do
              subject
              expect(address_with_shipment.reload.firstname).to eq 'Henry'
            end
          end
        end
      end
    end
  end
end
