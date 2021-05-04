require 'spec_helper'

module Spree
  describe Account::Update do
    subject { described_class }

    let!(:user)  { create(:user_with_addresses) }
    let(:result) { subject.call(user: user, user_params: user_params) }
    let!(:new_default_ship_address) { create(:address, user: user) }
    let!(:new_default_bill_address) { create(:address, user: user) }
    let(:value) { result.value }

    shared_examples 'user not created' do
      it 'does not create new user' do
        expect { result }.not_to change(Spree.user_class, :count)
      end
    end

    shared_examples 'successful response' do
      it 'result is successful' do
        expect(result).to be_success
      end
    end

    shared_examples 'updated attributes' do
      it 'updates user with given params' do
        expect(value).to have_attributes(user_params)
      end
    end

    shared_examples 'both default addresses changed' do
      it 'changes both default bill address and ship address' do
        expect(user.bill_address).not_to eq(new_default_bill_address)
        expect(user.ship_address).not_to eq(new_default_ship_address)

        expect(value.bill_address_id).to eq(new_default_bill_address.id)
        expect(value.ship_address_id).to eq(new_default_ship_address.id)
      end
    end

    describe '#call' do
      context 'with valid params' do
        context 'when all params are given' do
          let(:user_params) do
            {
              email: 'new_email@email.com',
              bill_address_id: new_default_bill_address.id,
              ship_address_id: new_default_ship_address.id
            }
          end

          it_behaves_like 'user not created'
          it_behaves_like 'successful response'
          it_behaves_like 'updated attributes'
          it_behaves_like 'both default addresses changed'
        end

        context 'when only address params are given' do
          let(:user_params) do
            {
              bill_address_id: new_default_bill_address.id,
              ship_address_id: new_default_ship_address.id
            }
          end

          it_behaves_like 'user not created'
          it_behaves_like 'successful response'
          it_behaves_like 'updated attributes'
          it_behaves_like 'both default addresses changed'

          context 'when only bill address is given' do
            let(:user_params) do
              {
                bill_address_id: new_default_bill_address.id
              }
            end

            it_behaves_like 'user not created'
            it_behaves_like 'successful response'
            it_behaves_like 'updated attributes'

            it 'changes only user default bill address' do
              expect(user.bill_address).not_to eq(new_default_bill_address)
              expect(user.ship_address).not_to eq(new_default_ship_address)

              expect(value.bill_address_id).to eq(new_default_bill_address.id)
              expect { result }.not_to change(value, :ship_address_id)
            end
          end

          context 'when only ship address is given' do
            let(:user_params) do
              {
                ship_address_id: new_default_ship_address.id
              }
            end

            it_behaves_like 'user not created'
            it_behaves_like 'successful response'
            it_behaves_like 'updated attributes'

            it 'changes only user default ship address' do
              expect(user.bill_address).not_to eq(new_default_bill_address)
              expect(user.ship_address).not_to eq(new_default_ship_address)

              expect(value.ship_address_id).to eq(new_default_ship_address.id)
              expect { result }.not_to change(value, :bill_address_id)
            end
          end
        end

        context 'when no params are given' do
          let(:user_params) do
            {}
          end

          it_behaves_like 'user not created'
          it_behaves_like 'successful response'

          it 'does not change user data at all' do
            expect(value).to have_attributes(user.attributes)
          end
        end
      end
    end
  end
end
