require 'spec_helper'

module Spree
  module Admin
    describe AddressesController, type: :controller do
      stub_authorization!

      let(:order) { mock_model(Spree::Order, save: true) }
      let(:shipment) { mock_model(Spree::Shipment, save: true, order: order) }
      let(:address) { mock_model(Spree::Address, save: true) }

      describe '#attach_shipment' do
        let(:order_address) { mock_model(Spree::Address, save: true) }
        let(:address_params) { { firstname: 'first', lastname: 'last' } }

        def send_request(params={})
          spree_patch :attach_shipment, params.merge(shipment_id: shipment.id, address: address_params)
        end

        before(:each) do
          allow(Spree::Shipment).to receive(:find).with(shipment.id.to_s).and_return(shipment)
          allow(shipment).to receive(:address).and_return(address)
          allow(order).to receive(:ship_address).and_return(order_address)
          allow(address).to receive(:attributes=)
        end

        describe '#load_shipment' do
          before(:each) do
            allow(Spree::Shipment).to receive(:find).with(shipment.id).and_return(shipment)
          end

          it 'assigns shipment' do
            send_request
            expect(assigns(:shipment)).to eq shipment
          end
        end

        describe '#load_address' do
          context 'when shipment address present' do
            before(:each) do
              allow(shipment).to receive(:address).and_return(address)
            end

            context 'when shipment address is not same as order ship address' do
              before(:each) do
                allow(order).to receive(:ship_address).and_return(order_address)
              end

              it 'loads shipment address' do
                send_request
                expect(assigns(:address)).to eq address
              end
            end

            context 'when shipment address is same as order ship address' do
              let(:new_address) { mock_model(Spree::Address) }
              before(:each) do
                allow(order).to receive(:ship_address).and_return(address)
                allow(shipment).to receive(:build_address).and_return(new_address)
                allow(new_address).to receive(:attributes=)
                allow(shipment).to receive(:save).and_return(true)
                allow(controller).to receive(:apply_to_other_shipments)
              end

              it 'builds shipment address' do
                expect(shipment).to receive(:build_address)
                send_request
              end

              it 'loads new address' do
                send_request
                expect(assigns(:address)).to eq new_address
              end
            end
          end

          context 'when shipment address not present' do
            let(:new_address) { mock_model(Spree::Address) }
            before(:each) do
              allow(shipment).to receive(:address).and_return(nil)
              allow(shipment).to receive(:build_address).and_return(new_address)
              allow(new_address).to receive(:attributes=)
              allow(shipment).to receive(:save).and_return(true)
              allow(controller).to receive(:apply_to_other_shipments)
            end

            it 'builds shipment address' do
              expect(shipment).to receive(:build_address)
              send_request
            end

            it 'loads new address' do
              send_request
              expect(assigns(:address)).to eq new_address
            end
          end
        end

        it 'assigns address attributes with address params' do
          expect(address).to receive(:attributes=).with(ActionController::Parameters.new(address_params).permit(permitted_address_attributes))
          send_request
        end

        it 'attempts to save shipment' do
          allow(controller).to receive(:apply_to_other_shipments)
          expect(shipment).to receive(:save).and_return(true)
          send_request
        end

        context 'when shipment is saved successfully' do
          before(:each) do
            allow(shipment).to receive(:save).and_return(true)
          end

          describe '#apply_to_other_shipments' do
            let(:other_shipment) { mock_model(Spree::Shipment, save: true) }

            context 'when params has apply_to_other_shipments' do
              before(:each) do
                allow(Spree::Shipment).to receive(:find).with(other_shipment.id.to_s).and_return(other_shipment)
                allow(other_shipment).to receive(:update_attributes).with(address_id: address.id)
              end

              it 'finds other shipment' do
                expect(Spree::Shipment).to receive(:find).with(other_shipment.id.to_s).and_return(other_shipment)
                send_request(apply_to_other_shipments: [other_shipment.id])
              end

              it 'applies to address to other shipment' do
                expect(other_shipment).to receive(:update_attributes).with(address_id: address.id)
                send_request(apply_to_other_shipments: [other_shipment.id])
              end
            end
          end

          it 'sets flash success' do
            send_request
            expect(flash[:success]).to eq(Spree.t(:successfully_updated, resource: 'Shipment'))
          end
        end

        context 'when shipment is not saved successfully' do
          before(:each) do
            allow(shipment).to receive(:save).and_return(false)
            allow(address).to receive_message_chain(:errors, :full_messages).and_return(['test error'])
          end

          it 'do not address apply_to_other_shipments' do
            expect(controller).to_not receive(:apply_to_other_shipments)
            send_request
          end

          it 'sets flash error' do
            send_request
            expect(flash[:error]).to eq('test error')
          end
        end

        it 'redirects to edit order path' do
          send_request
          expect(response).to redirect_to edit_admin_order_path(order)
        end
      end
    end
  end
end
