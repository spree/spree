require 'spec_helper'

describe Spree::Address, type: :model do
  it_behaves_like 'metadata'

  describe 'after_commit :async_geocode' do
    let(:address) { build(:address) }


    it 'geocodes the address in the background' do
      expect { address.save! }.
        to have_enqueued_job(Spree::Addresses::GeocodeAddressJob).
        on_queue(Spree.queues.addresses).
        exactly(:once)

      job = Spree::Addresses::GeocodeAddressJob.queue_adapter.enqueued_jobs.last
      expect(job['arguments']).to contain_exactly(address.id)
    end

    context "when geocoding data didn't change" do
      before { address.save! }

      it 'skips geocoding' do
        expect { address.update!(company: 'New Test Company') }.to_not have_enqueued_job(Spree::Addresses::GeocodeAddressJob)
      end
    end
  end

  context 'default values' do
    context 'with a customer owner' do
      let(:user) { create(:user, first_name: 'John', last_name: 'Snow') }
      let(:address) { Spree::Address.new(owner: user) }

      it 'sets owner_id and first/last name from the customer' do
        expect(address.owner_id).to eq(user.id)
        expect(address.first_name).to eq('John')
        expect(address.last_name).to eq('Snow')
      end
    end
  end

  describe 'clone (deprecated, becomes the standard Ruby clone in 6.1)' do
    before { allow(Spree::Deprecation).to receive(:warn) }

    it 'warns and points at #snapshot' do
      create(:address).clone

      expect(Spree::Deprecation).to have_received(:warn).with(/#snapshot/)
    end

    it 'creates a copy of the address with the exception of the id, label, owner, updated_at and created_at attributes' do
      state = create(:state)
      original = create(:address,
                        label: 'Home',
                        customer: create(:customer),
                        address1: FFaker::Address.street_address,
                        address2: FFaker::Address.secondary_address,
                        alternative_phone: FFaker::PhoneNumberAU.mobile_phone_number,
                        city: FFaker::AddressUS.city,
                        country: Spree::Country.by_iso('US'),
                        first_name: FFaker::Name.first_name,
                        last_name: FFaker::Name.last_name,
                        company: FFaker::Company.name,
                        phone: FFaker::PhoneNumber.short_phone_number,
                        state: state,
                        state_name: state.name,
                        postal_code: Spree::TestingSupport::CountryPool.postal_code_for('US'))

      cloned = original.clone

      expect(cloned.address1).to eq(original.address1)
      expect(cloned.address2).to eq(original.address2)
      expect(cloned.alternative_phone).to eq(original.alternative_phone)
      expect(cloned.city).to eq(original.city)
      expect(cloned.country_code).to eq(original.country_code)
      expect(cloned.first_name).to eq(original.first_name)
      expect(cloned.last_name).to eq(original.last_name)
      expect(cloned.company).to eq(original.company)
      expect(cloned.phone).to eq(original.phone)
      expect(cloned.state_abbr).to eq(original.state_abbr)
      expect(cloned.state_name).to eq(original.state_name)
      expect(cloned.postal_code).to eq(original.postal_code)

      expect(cloned.user_id).to be_nil
      expect(cloned.label).to be_nil

      expect(cloned.id).not_to eq(original.id)
      expect(cloned.created_at).not_to eq(original.created_at)
      expect(cloned.updated_at).not_to eq(original.updated_at)
    end
  end

  describe 'delegated method' do
    context 'Country' do
      let(:country) { @default_store.default_country }
      let(:address) { create(:address, country: country) }

      context '#country_name' do
        it 'return proper country_iso_name' do
          expect(address.country_name).to eq 'United States'
        end
      end

      context '#country_iso_name' do
        it 'return proper country_iso_name' do
          expect(address.country_iso_name).to eq 'UNITED STATES OF AMERICA'
        end
      end

      context '#country_code' do
        it 'return proper country_iso_name' do
          expect(address.country_code).to eq 'US'
        end
      end

      context '#country_iso3' do
        it 'return proper country_iso_name' do
          expect(address.country_iso3).to eq 'USA'
        end
      end
    end
  end

  context 'aliased attributes' do
    let(:address) { Spree::Address.new }

    it 'first_name' do
      address.first_name = 'Ryan'
      expect(address.first_name).to eq('Ryan')
    end

    it 'last_name' do
      address.last_name = 'Bigg'
      expect(address.last_name).to eq('Bigg')
    end
  end

  context 'validation' do
    # Countries and subdivisions are reference data now, so these are real
    # places rather than invented ones: Maryland is a subdivision of the US,
    # and Poland requires no subdivision at all.
    let(:country) { Spree::Country.by_iso('US') }
    let(:state) { Spree::State.resolve('US', 'MD') }
    let(:stateless_country) { Spree::Country.by_iso('PL') }
    let(:address) { build(:address, country: country, state: nil) }

    it 'state_name is not nil and country does not have any states' do
      address.country_code = stateless_country.iso
      address.postal_code = Spree::TestingSupport::CountryPool.postal_code_for('PL')
      address.state_code = nil
      address.state_name = 'Somewhere'
      expect(address).to be_valid
    end

    it 'errors when state_name is nil' do
      address.state_name = nil
      address.state_code = nil
      expect(address).not_to be_valid
    end

    # Erasure truncates a postcode to the part that establishes where a sale
    # was taxed, so a stored value can be shorter than its country's format.
    # The formatter indexes backwards to place the separator and raises on a
    # short one — saving such a row has to fail validation, not blow up.
    it 'refuses a postcode too short for its country without raising' do
      short = build(:address, country_code: 'GB', state_code: nil, state_name: 'London',
                              postal_code: 'NW')

      expect { short.valid? }.not_to raise_error
      expect(short).not_to be_valid
    end

    it 'full state name is in state_name and country does contain that state' do
      address.state_name = 'Maryland'
      expect(address).to be_valid
      expect(address.state).not_to be_nil
      expect(address.state_name).to be_nil
    end

    it 'state abbr is in state_name and country does contain that state' do
      address.state_name = state.abbr
      expect(address).to be_valid
      expect(address.state_abbr).to eq('MD')
      expect(address.state_name).to be_nil
    end

    it 'state is entered but country does not contain that state' do
      address.state_code = state.abbr
      address.country_code = 'CA'
      address.postal_code = Spree::TestingSupport::CountryPool.postal_code_for('CA')
      address.valid?
      # The Maryland code means nothing in Canada, so it is dropped and the
      # address is left with no subdivision at all.
      expect(address.errors['state']).to eq(["can't be blank"])
    end

    it 'both state and state_name are entered but country does not contain the state' do
      address.state_code = state.abbr
      address.state_name = 'maryland'
      address.country_code = stateless_country.iso
      address.postal_code = Spree::TestingSupport::CountryPool.postal_code_for('PL')
      expect(address).to be_valid
      expect(address.state_abbr).to be_nil
    end

    it 'both state and state_name are entered and country does contain the state' do
      address.state_code = state.abbr
      address.state_name = 'maryland'
      expect(address).to be_valid
      expect(address.state_name).to be_nil
    end

    it 'does not require a state when the country does not require one' do
      address.country_code = stateless_country.iso
      address.postal_code = Spree::TestingSupport::CountryPool.postal_code_for(stateless_country.iso)
      address.state_code = nil
      address.state_name = nil
      expect(address).to be_valid
    end

    it 'does not require phone' do
      address.state_code = state.abbr
      address.phone = ''
      expect(address).to be_valid
    end

    context 'when phone is required' do
      before { @default_store.update!(preferred_address_requires_phone: true) }

      after { @default_store.update!(preferred_address_requires_phone: false) }

      it 'validates presence of the phone' do
        address.phone = ''
        address.valid?
        expect(address.errors['phone']).to eq(["can't be blank"])
      end
    end

    context 'when company is required' do
      it 'validates presence of the company' do
        stub_store_preferences(company_field_enabled: true, address_requires_company: true)

        address.company = ''
        address.valid?
        expect(address.errors['company']).to eq(["can't be blank"])
      end

      # Requiring a field the customer is never shown would make checkout
      # unfinishable, so the requirement follows the field being on the form.
      it 'stays optional while the company field is hidden' do
      address.state_code = state.abbr
        stub_store_preferences(company_field_enabled: false, address_requires_company: true)

        address.company = ''
        expect(address).to be_valid
      end
    end

    it 'requires postal_code' do
      address.postal_code = ''
      address.valid?
      expect(address.errors['postal_code']).to include("can't be blank")
    end

    it 'requires first_name' do
      address.first_name = ''
      address.valid?
      expect(address.errors['first_name']).to include("can't be blank")
    end

    it 'requires last_name' do
      address.last_name = ''
      address.valid?
      expect(address.errors['last_name']).to include("can't be blank")
    end

    context 'postal code validation' do
      it 'validates the postal code' do
        allow(address.country).to receive(:iso).and_return('US')
        address.postal_code = 'abc'
        address.valid?
        expect(address.errors['postal_code']).to include('is invalid')
      end

      it 'accepts a zip code with surrounding white space' do
        allow(address.country).to receive(:iso).and_return('US')
        address.postal_code = ' 12345 '
        address.valid?
        expect(address.errors['postal_code']).not_to include('is invalid')
      end

      it 'accepts an unformatted zip code' do
        address.country_code = 'GB'
        address.postal_code = '	AL38QE'
        address.valid?
        expect(address.errors['postal_code']).not_to include('is invalid')
      end

      context 'does not validate' do
        it 'is for quick checkout' do
          address.postal_code = 'abc'
          address.quick_checkout = true
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end

        it 'does not have a country' do
          address.country_code = nil
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end

        it 'country does not require a postal code' do
          allow(address.country).to receive(:zipcode_required?).and_return(false)
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end

        it 'does not have an iso' do
          allow(address.country).to receive(:iso).and_return(nil)
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end

        it 'does not have a postal code' do
          address.postal_code = ''
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end

        it 'postal code is nil' do
          address.postal_code = nil
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end

        it 'does not have a supported country iso' do
          allow(address.country).to receive(:iso).and_return('XX')
          address.valid?
          expect(address.errors['postal_code']).not_to include('is invalid')
        end
      end
    end

    context 'phone not required' do
      before { allow(address).to receive_messages require_phone?: false }

      it 'shows no errors when phone is blank' do
        address.phone = ''
        address.valid?
        expect(address.errors[:phone].size).to eq 0
      end
    end

    context 'postal code not required' do
      before { allow(address).to receive_messages require_postal_code?: false }

      it 'shows no errors when phone is blank' do
        address.postal_code = ''
        address.valid?
        expect(address.errors[:postal_code].size).to eq 0
      end
    end
  end

  describe 'after create' do
    context 'when user is assigned and it has default name' do
      it 'should assign address name to the user' do
        user = create(:user, first_name: nil, last_name: nil)
        create(:address, customer: user, first_name: 'John', last_name: 'Doe')

        expect(user.reload.first_name).to eq 'John'
        expect(user.reload.last_name).to eq 'Doe'
      end
    end
  end

  context '#full_name' do
    context 'both first and last names are present' do
      let(:address) { create(:address, first_name: 'Michael', last_name: 'Jackson') }

      specify { expect(address.full_name).to eq('Michael Jackson') }
    end
  end

  context '#state_text' do
    # Virginia is a real US subdivision, so the code is what gets stored.
    let(:virginia) { Spree::State.resolve('US', 'VA') }

    context 'state is blank' do
      # A country that requires no subdivision keeps free text as-is.
      let(:address) { create(:address, country: Spree::Country.by_iso('PL'), postal_code: '00-001', state: nil, state_name: 'Somewhere Else') }

      specify { expect(address.state_text).to eq('Somewhere Else') }
    end

    context 'the subdivision is known' do
      let(:address) { create(:address, state: virginia) }

      specify { expect(address.state_text).to eq('VA') }
    end
  end

  context '#state_name_text' do
    let(:virginia) { Spree::State.resolve('US', 'VA') }

    context 'state_name is blank' do
      let(:address) { create(:address, state: virginia, state_name: nil) }

      specify { expect(address.state_name_text).to eq('Virginia') }
    end

    context 'state is blank' do
      let(:address) { create(:address, country: Spree::Country.by_iso('PL'), postal_code: '00-001', state: nil, state_name: 'Somewhere Else') }

      specify { expect(address.state_name_text).to eq('Somewhere Else') }
    end
  end

  describe '#country_code' do
    let(:address) { build(:address, country: country) }
    let(:country) { Spree::Country.by_iso('US') }

    it 'returns the country iso' do
      expect(address.country_code).to eq('US')
    end

    it 'returns nil if the country is nil' do
      address.country_code = nil
      expect(address.country_code).to be_nil
    end
  end

  context 'defines require_phone? helper method' do
    let(:address) { create(:address) }

    specify { expect(address.instance_eval { require_phone? }).to be(false) }
  end

  context '#clear_state' do
    let (:address) { create(:address) }

    before { address.state_name = 'maryland' }

    it { expect { address.send(:clear_state) }.to change(address, :state).to(nil).from(address.state) }
    it { expect { address.send(:clear_state) }.not_to change(address, :state_name) }
  end

  context '#clear_state_name' do
    let (:address) { create(:address) }

    before { address.state_name = 'maryland' }

    it { expect { address.send(:clear_state_name) }.not_to change(address, :state_abbr) }
    it { expect { address.send(:clear_state_name) }.to change(address, :state_name).to(nil).from('maryland') }
  end

  context '#clear_invalid_state_entities' do
    # Pinned rather than drawn from the factory pool: the contexts below move
    # the address to Japan to prove a foreign subdivision is dropped, which
    # only holds while the starting country isn't Japan itself.
    let(:country) { Spree::Country.by_iso('US') }
    let(:state) { Spree::State.resolve('US', 'NY') }
    let (:address) { create(:address, country: country, state: state) }

    def clear_state_entities
      address.send(:clear_invalid_state_entities)
    end

    context 'state not present and state_name both not present' do
      before do
        address.state_code = nil
        address.state_name = nil
        clear_state_entities
      end

      it { expect(address.state).to be_nil }
      it { expect(address.state_name).to be_nil }
    end

    context 'state_name not present and state present ' do
      before { address.state_name = nil }

      context 'state belongs to a different country than to which address is associated' do
        before do
          # Japan's subdivision codes are numeric, so a US code cannot
          # coincidentally be valid there.
          address.country_code = 'JP'
          address.postal_code = Spree::TestingSupport::CountryPool.postal_code_for('JP')
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to be_nil }
      end

      context 'state belongs to the same country associated with address' do
        before { clear_state_entities }

        it { expect(address.state).to eq(state) }
        it { expect(address.state_name).to be_nil }
      end
    end

    context 'state not present and state_name present' do
      before do
        address.state_code = nil
        address.state_name = state.name
      end

      context 'when country has no states and state is required' do
        before do
          address.country_code = 'US'
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to eq(state.name) }
      end

      context 'when country has states' do
        before do
          address.state_name = state.name
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to eq(state.name) }
      end

      context 'when country has no states and state is not required' do
        before do
          # Hong Kong genuinely has no subdivisions in the ISO data.
          address.country_code = 'HK'
          address.state_name = state.name
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        # A country with no subdivisions has nothing to match the text
        # against, so it stays as the customer typed it.
        it { expect(address.state_name).to eq(state.name) }
      end
    end
  end

  context '#==' do
    let(:address) { create(:address) }
    let(:address2) { address.snapshot }

    context 'same addresses' do
      it { expect(address == address2).to eq(true) }
    end

    context 'different addresses' do
      before { address2.first_name = 'Someone Else' }

      it { expect(address == address2).to eq(false) }
    end
  end

  context 'editable & destroy' do
    subject(:destroy_address) { address.destroy }

    let(:address) { create(:address, customer: user) }
    let(:address2) { create(:address, customer: user) }
    let(:address3) { create(:address, customer: user) }

    let(:order) { create(:completed_order_with_totals) }
    let(:user) { create(:user) }

    before { order.update_attribute(:bill_address, address2) }

    it 'has required attributes' do
      # Every conditionally-required field, whatever the store's settings —
      # phone and company both default to off.
      expect(Spree::Address.required_fields).to eq([:first_name, :last_name, :address1, :city, :country, :postal_code, :phone, :company])
    end

    it 'is editable' do
      expect(address).to be_editable
    end

    it 'can be deleted' do
      expect(address).to be_can_be_deleted
    end

    it "isn't editable when there is an associated order" do
      expect(address2).to_not be_editable
    end

    it "can't be deleted when there is an associated order" do
      expect(address2).to_not be_can_be_deleted
    end

    it 'can be deleted when there is an incomplete associated order' do
      expect(address3).to be_can_be_deleted
    end

    it 'is destroyed without saving used' do
      address.destroy
      expect(Spree::Address.where(['id = (?)', address.id])).to be_empty
    end

    it 'is destroyed deleted timestamp' do
      address2.destroy
      expect(Spree::Address.where(['id = (?)', address2.id])).not_to be_empty
      expect(Spree::Address.not_deleted.where(['id = (?)', address2.id])).to be_empty
    end

    context 'when an incomplete order references the address' do
      let!(:incomplete_order) do
        create(:order, customer: user, bill_address: address, ship_address: address, state: 'delivery')
      end

      it 'detaches the address from the order and resets it to the address step' do
        address.destroy

        incomplete_order.reload
        expect(incomplete_order.bill_address_id).to be_nil
        expect(incomplete_order.ship_address_id).to be_nil
        expect(incomplete_order.reload.completed_at).to be_nil
      end

      it 'still hard-deletes the address' do
        address.destroy
        expect(Spree::Address.where(id: address.id)).to be_empty
      end

      it "leaves another user's order referencing the same address untouched" do
        other_order = create(:order, customer: create(:user), bill_address: address, ship_address: address, state: 'delivery')

        address.destroy

        expect(other_order.reload.ship_address_id).to eq(address.id)
        expect(other_order.bill_address_id).to eq(address.id)
        expect(other_order.reload.ship_address_id).to eq(address.id)
      end

      context 'when the address is also used by a completed order' do
        let!(:completed_order) do
          create(:completed_order_with_totals, bill_address: address, ship_address: address)
        end

        it 'soft-deletes the address and keeps it associated to all orders' do
          address.destroy

          expect(address.reload.deleted_at).to be_present
          expect(incomplete_order.reload.bill_address_id).to eq(address.id)
          expect(incomplete_order.ship_address_id).to eq(address.id)
          expect(completed_order.reload.bill_address_id).to eq(address.id)
        end
      end
    end

    context 'when saving user raises error' do
      before do
        user.update(ship_address: address2, bill_address: address2)
        user.reload
        allow_any_instance_of(Spree.customer_class).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)
      end

      it 'does not set deleted_at attribute for address' do
        expect { address2.destroy }.to raise_error(ActiveRecord::RecordInvalid)
        expect(address2.reload.deleted_at).to be_nil
      end
    end

    describe '#assign_new_default_address_to_user' do
      shared_examples 'default address' do
        context 'when 2 addresses are available' do
          let!(:address2_quick_checkout) { create(:address, customer: user, quick_checkout: true) }
          let!(:address3) { create(:address, customer: user) }

          it 'assigns last available address as default to bill and ship address' do
            user.update!(bill_address: address, ship_address: address)
            destroy_address
            expect(user.bill_address).to eq(address3)
            expect(user.ship_address).to eq(address3)

            address3.destroy

            expect(user.bill_address).to eq(address2)
            expect(user.ship_address).to eq(address2)
          end
        end

        context 'when the only address left is invalid' do
          before do
            address2.update_columns(address1: nil, city: nil, postal_code: nil, phone: nil)
            user.update_columns(bill_address_id: address.id, ship_address_id: address.id)
          end

          it 'does not raise errors and sets addresses to nil' do
            expect { destroy_address }.not_to raise_error
            expect(user.bill_address).to be_nil
            expect(user.ship_address).to be_nil
          end
        end

        context 'when the only address left is soft-deleted' do
          before do
            address2.update_columns(deleted_at: Time.current)
          end

          it 'does not raise errors and sets addresses to nil' do
            expect { destroy_address }.not_to raise_error
            expect(user.bill_address).to be_nil
            expect(user.ship_address).to be_nil
          end
        end

        context 'when deleted address was not assigned to the user' do
          before { address.update(owner: nil) }

          it 'does not touch user' do
            expect{ destroy_address }.not_to change{ user.reload.updated_at }
          end
        end

        context 'when deleted address was not default' do
          before do
            user.update_columns(bill_address_id: address2.id, ship_address_id: address2.id)
            user.reload
          end

          it 'does not change user bill address' do
            expect{ destroy_address }.not_to change{ user.reload.bill_address_id }
          end

          it 'does not change user ship address' do
            expect{ destroy_address }.not_to change{ user.reload.ship_address_id }
          end
        end
      end

      context 'when address is deleted' do
        it 'is deleted' do
          destroy_address
          expect(Spree::Address.find_by(id: address.id)).to be_nil
        end

        it_behaves_like 'default address'
      end

      context 'when address is soft deleted' do
        let!(:order) { create(:completed_order_with_totals, bill_address: address, ship_address: address) }

        it 'is soft deleted' do
          destroy_address
          expect(Spree::Address.find_by(id: address.id).deleted_at).to be_present
        end

        it_behaves_like 'default address'
      end
    end
  end

  describe '#normalized_postal_code' do
    it 'strips spaces and dashes and upcases' do
      expect(build(:address, postal_code: ' sw1a 1-aa ').normalized_postal_code).to eq('SW1A1AA')
      expect(build(:address, postal_code: nil).normalized_postal_code).to eq('')
    end
  end

  describe '#to_s' do
    let(:address) { create(:address) }

    it 'is displayed as string' do
      a = address
      expect(address.to_s).to eq("#{a.full_name}<br/>#{a.company}<br/>#{a.address1}<br/>#{a.address2}<br/>#{a.city}, #{a.state_text} #{a.postal_code}<br/>#{a.country}")
      address.company = nil
      expect(address.to_s).to eq("#{a.full_name}<br/>#{a.address1}<br/>#{a.address2}<br/>#{a.city}, #{a.state_text} #{a.postal_code}<br/>#{a.country}")
    end

    context 'address contains HTML' do
      it 'properly escapes HTML' do
        dangerous_string = '<script>alert("BOOM!")</script>'
        address = create(:address, first_name: dangerous_string)

        expect(address.to_s).not_to include(dangerous_string)
      end
    end
  end

  context 'address validators' do
    it 'runs through all configured validators during validation' do
      address = create(:address)
      expect_any_instance_of(Spree::Addresses::PhoneValidator).to receive(:validate).with(address)
      address.valid?
    end
  end

  context 'require_phone?' do
    context 'when quick_checkout is true' do
      let(:address) { create(:address, quick_checkout: true) }

      it 'returns false' do
        expect(address.require_phone?).to be(false)
      end
    end

    context 'when quick_checkout is false' do
      let(:address) { build_stubbed(:address, quick_checkout: false) }

      context 'and the store requires a phone' do
        before { @default_store.update!(preferred_address_requires_phone: true) }

        after { @default_store.update!(preferred_address_requires_phone: false) }

        it 'returns true' do
          expect(address.require_phone?).to be(true)
        end
      end

      context 'and the store does not require a phone' do
        before { @default_store.update!(preferred_address_requires_phone: false) }

        it 'returns false' do
          expect(address.require_phone?).to be(false)
        end
      end
    end

    context 'when there is no current store' do
      let(:address) { build_stubbed(:address, quick_checkout: false) }

      before { allow(Spree::Current).to receive(:store).and_return(nil) }

      it 'falls back to the preference default' do
        expect(address.require_phone?).to be(false)
      end
    end
  end

  describe 'country_code= and state_code= writer methods' do
    let(:country) { Spree::Country.by_iso('US') }
    let!(:state) { Spree::State.resolve(country.iso, 'NY') }

    describe '#country_code=' do
      it 'sets country from ISO code on validation' do
        address = build(:address, country: nil)
        address.country_code = 'US'
        address.valid?
        expect(address.country).to eq(country)
      end

      it 'is case-insensitive' do
        address = build(:address, country: nil)
        address.country_code = 'us'
        address.valid?
        expect(address.country).to eq(country)
      end

      it 'clears the country when blank — a posted empty value means empty' do
        original_country = create(:country)
        address = build(:address, country: original_country)
        address.country_code = ''
        address.valid?
        expect(address.country).to be_nil
      end

      it 'sets country to nil when ISO is not found' do
        address = build(:address, country: nil)
        address.country_code = 'XX'
        address.valid?
        expect(address.country).to be_nil
      end

      it 'clears the input after normalization' do
        address = build(:address, country: nil)
        address.country_code = 'US'
        address.valid?
        # The input should be cleared so it doesn't re-run on next validation
        address.valid?
        expect(address.country).to eq(country)
      end
    end

    describe '#state_code=' do
      it 'sets state from abbreviation on validation' do
        address = build(:address, country: country, state: nil)
        address.state_code = 'NY'
        address.valid?
        expect(address.state).to eq(state)
      end

      it 'requires country to be set first' do
        address = build(:address, country: nil, state: nil)
        address.state_code = 'NY'
        address.valid?
        expect(address.state).to be_nil
      end

      it 'does nothing when abbreviation is blank' do
        address = build(:address, country: country, state: nil)
        address.state_code = ''
        address.valid?
        expect(address.state).to be_nil
      end

      it 'sets state to nil when abbreviation is not found for country' do
        address = build(:address, country: country, state: nil)
        address.state_code = 'XX'
        address.valid?
        expect(address.state).to be_nil
      end

      it 'only finds states belonging to the address country' do
        other_country = create(:country, iso: 'CA')
        other_state = create(:state, country: other_country, abbr: 'NY', name: 'Not York')

        address = build(:address, country: country, state: nil)
        address.state_code = 'NY'
        address.valid?
        expect(address.state).to eq(state)
        expect(address.state).not_to eq(other_state)
      end
    end

    describe 'combined country_code and state_abbr' do
      it 'sets both country and state when both are provided' do
        address = build(:address, country: nil, state: nil)
        address.country_code = 'US'
        address.state_abbr = 'NY'
        address.valid?
        expect(address.country).to eq(country)
        expect(address.state).to eq(state)
      end

      it 'works with new address creation' do
        address = Spree::Address.new(
          first_name: 'John',
          last_name: 'Doe',
          address1: '123 Main St',
          city: 'New York',
          postal_code: '10001',
          phone: '555-1234',
          country_code: 'US',
          state_abbr: 'NY'
        )
        expect(address).to be_valid
        expect(address.country).to eq(country)
        expect(address.state).to eq(state)
      end

      it 'works with address update via assign_attributes' do
        address = create(:address)
        address.assign_attributes(country_code: 'US', state_abbr: 'NY')
        address.valid?
        expect(address.country).to eq(country)
        expect(address.state).to eq(state)
      end
    end
  end

  # The pre-6.0 names stay callable for one release. Nothing in core calls
  # them, so without these they could break unnoticed.
  describe 'deprecated postal-code helpers' do
    it 'normalizes through the class-level shell' do
      expect(Spree::Deprecation).to receive(:warn).with(/normalize_zipcode/)

      expect(described_class.normalize_zipcode(' sw1a 1-aa ')).to eq('SW1A1AA')
    end

    it 'normalizes this address through the instance shell' do
      address = build(:address, postal_code: ' sw1a 1-aa ')
      expect(Spree::Deprecation).to receive(:warn).with(/normalized_zipcode/)

      expect(address.normalized_zipcode).to eq('SW1A1AA')
    end
  end

  describe '#require_postal_code?' do
    # The pre-6.0 name stays overridable for one release: a decorator's
    # require_zipcode? sits ahead of Spree::Address in the ancestry, so it
    # still decides. Otherwise the override would stop being called silently.
    it 'honors a host app override of the pre-6.0 require_zipcode?' do
      overridden = Class.new(Spree::Address) do
        def require_zipcode?
          false
        end
      end

      expect(overridden.new.require_postal_code?).to be(false)
    end
  end

  describe '.find_duplicate' do
    let(:country) { create(:country, iso: 'US') }
    let(:state) { create(:state, country: country, abbr: 'NY', name: 'New York') }
    let!(:address) { create(:address, country: country, state: state, address1: '1 Dup Lane') }

    it 'finds an address matching the given attributes' do
      attributes = address.attributes.symbolize_keys.slice(:first_name, :last_name, :address1, :city, :postal_code, :country_code, :state_code)

      expect(described_class.find_duplicate(attributes)).to eq(address)
    end

    it 'matches a state given by name rather than code' do
      attributes = address.attributes.symbolize_keys.
                   slice(:first_name, :last_name, :address1, :city, :postal_code, :country_code).
                   merge(state_name: 'New York')

      expect(described_class.find_duplicate(attributes)).to eq(address)
    end

    it 'ignores identity and timestamp keys' do
      attributes = address.attributes.symbolize_keys.
                   slice(:first_name, :last_name, :address1, :city, :postal_code, :country_code, :state_code).
                   merge(id: 0, created_at: 1.day.ago, updated_at: 1.day.ago)

      expect(described_class.find_duplicate(attributes)).to eq(address)
    end

    it 'does not match a deleted address' do
      address.update_column(:deleted_at, Time.current)
      attributes = address.attributes.symbolize_keys.slice(:first_name, :last_name, :address1, :city, :postal_code, :country_code, :state_code)

      expect(described_class.find_duplicate(attributes)).to be_nil
    end

    it 'returns nil when nothing matches' do
      expect(described_class.find_duplicate(address1: 'nowhere at all')).to be_nil
    end

    # The renamed columns are still accepted under their pre-6.0 write names,
    # and a query builder matches on the literal key rather than the alias.
    it 'matches attributes given under the legacy write names' do
      attributes = address.attributes.symbolize_keys.
                   slice(:address1, :city, :country_code, :state_code).
                   merge(firstname: address.first_name, lastname: address.last_name, zipcode: address.postal_code)

      expect(described_class.find_duplicate(attributes)).to eq(address)
    end
  end

  describe '#snapshot' do
    let(:customer) { create(:customer) }
    let(:address) { create(:address, owner: customer, label: 'Home') }

    subject(:snapshot) { address.snapshot }

    it 'copies the address without an owner, so it stays out of the book it came from' do
      expect(snapshot.owner).to be_nil
      expect(snapshot.address1).to eq(address.address1)
      expect(snapshot.city).to eq(address.city)
      expect(snapshot.postal_code).to eq(address.postal_code)
    end

    it 'drops the label, which belongs to the entry in the book' do
      expect(snapshot.label).to be_nil
    end

    it 'is a new record' do
      expect(snapshot).to be_new_record
    end

    it 'lets two snapshots of the same labelled address be saved side by side' do
      expect(address.snapshot.save).to be(true)
      expect(address.snapshot.save).to be(true)
    end
  end

  describe '#duplicate_in_address_book' do
    let(:customer) { create(:customer) }
    let(:attributes) do
      { first_name: 'John', last_name: 'Doe', company: 'Company', address1: '1 Main St',
        address2: 'Northwest', city: 'New York', postal_code: '10001', state_code: 'NY',
        country_code: 'US', phone: '555-1212', alternative_phone: '555-1213' }
    end
    let!(:saved) { create(:address, attributes.merge(owner: customer)) }

    def build_for(owner, overrides = {})
      described_class.new(attributes.merge(overrides)).tap do |address|
        address.owner = owner
        address.valid?
      end
    end

    it 'finds the entry the book already holds' do
      expect(build_for(customer).duplicate_in_address_book).to eq(saved)
    end

    it 'ignores geocoding, which is derived from the address' do
      saved.update_columns(latitude: 40.7, longitude: -74.0)

      expect(build_for(customer).duplicate_in_address_book).to eq(saved)
    end

    it 'returns nil when the address differs' do
      expect(build_for(customer, address1: '2 Main St').duplicate_in_address_book).to be_nil
    end

    it 'returns nil for a deleted entry' do
      saved.update_column(:deleted_at, Time.current)

      expect(build_for(customer).duplicate_in_address_book).to be_nil
    end

    it 'never reaches into another owner\'s book' do
      expect(build_for(create(:customer)).duplicate_in_address_book).to be_nil
    end

    it 'returns nil without an owner' do
      expect(build_for(nil).duplicate_in_address_book).to be_nil
    end

    it 'does not match the address against itself' do
      expect(saved.duplicate_in_address_book).to be_nil
    end

    # The upgrade task copies the pre-6.0 foreign keys into codes and leaves
    # them populated, so comparing them would make every migrated entry differ
    # from every newly typed one and silently disable deduplication.
    it 'matches an entry still carrying the pre-6.0 country and state ids' do
      saved.update_columns(country_id: 42, state_id: 7)

      expect(build_for(customer).duplicate_in_address_book).to eq(saved)
    end

    # A label names the entry, not the place: "Dock A" and "Dock B" at one site
    # are two entries a company is entitled to keep.
    it 'does not match an entry filed under a different label' do
      saved.update!(label: 'Dock A')

      expect(build_for(customer, label: 'Dock B').duplicate_in_address_book).to be_nil
    end

    it 'matches an entry filed under the same label' do
      saved.update!(label: 'Dock A')

      expect(build_for(customer, label: 'Dock A').duplicate_in_address_book).to eq(saved)
    end

    it 'does not match when the request carries metadata the entry lacks' do
      built = build_for(customer)
      built.metadata = { 'gate_code' => '1234' }

      expect(built.duplicate_in_address_book).to be_nil
    end
  end
end
