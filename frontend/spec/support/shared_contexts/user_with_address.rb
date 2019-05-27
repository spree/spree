shared_context 'user with address' do
  let(:state) { Spree::State.all.first || create(:state) }

  let(:address) do
    create(:address, address1: FFaker::Address.street_address, state: state)
  end

  let(:billing) { build(:address, state: state) }
  let(:shipping) do
    build(:address, address1: FFaker::Address.street_address, state: state)
  end

  let(:user) do
    u = create(:user)
    u.addresses << address
    u.save
    u
  end
end
