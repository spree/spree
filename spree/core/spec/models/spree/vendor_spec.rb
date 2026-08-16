require 'spec_helper'

describe Spree::Vendor do
  let(:store) { @default_store }

  describe 'statuses' do
    it 'starts pending and moves only through workflows' do
      expect(described_class.default_status).to eq('pending')
      expect(described_class.statuses).to include('approved', 'suspended', 'rejected')
      # A state machine would have generated these; the absence is the point.
      expect(described_class).not_to respond_to(:state_machines)
    end

    it 'generates a predicate and a scope per status' do
      vendor = create(:vendor, :approved)

      expect(vendor).to be_approved
      expect(vendor).not_to be_pending
      expect(described_class.approved).to include(vendor)
    end

    it 'rejects an unknown status' do
      expect(build(:vendor, status: 'flourishing')).not_to be_valid
    end
  end

  describe 'slug' do
    it 'derives from the name when absent' do
      expect(create(:vendor, name: 'Bright Sparks Ltd').slug).to eq('bright-sparks-ltd')
    end

    it 'keeps an explicit slug' do
      expect(create(:vendor, name: 'Bright Sparks', slug: 'sparks').slug).to eq('sparks')
    end

    it 'is unique within a store' do
      create(:vendor, slug: 'sparks', store: store)

      expect(build(:vendor, slug: 'sparks', store: store)).not_to be_valid
    end

    it 'may repeat on another store' do
      create(:vendor, slug: 'sparks', store: store)

      expect(build(:vendor, slug: 'sparks', store: create(:store))).to be_valid
    end
  end

  describe '#sellable?' do
    it 'is true once approved' do
      expect(create(:vendor, :approved)).to be_sellable
    end

    it 'is false while unapproved' do
      expect(create(:vendor, :onboarding)).not_to be_sellable
    end

    # The catalog stays; what stops is selling.
    it 'is false while on holiday' do
      vendor = create(:vendor, :on_holiday)

      expect(vendor).to be_on_holiday
      expect(vendor).not_to be_sellable
      expect(described_class.sellable).not_to include(vendor)
    end

    it 'resumes once the holiday has passed' do
      vendor = create(:vendor, :approved, holiday_mode_until: 1.day.ago)

      expect(vendor).not_to be_on_holiday
      expect(described_class.sellable).to include(vendor)
    end
  end

  describe 'teams' do
    let(:vendor) { create(:vendor, :approved) }
    let(:staffer) { create(:admin_user, :without_admin_role) }

    it 'owns its own roles, separate from the store' do
      role = create(:role, name: 'Packer', resource: vendor)

      expect(vendor.roles).to include(role)
      expect(store.roles).not_to include(role)
    end

    it 'adds a user through a role it owns' do
      vendor.add_user(staffer, create(:role, name: 'Packer', resource: vendor))

      expect(vendor.users).to include(staffer)
      expect(staffer.vendors).to include(vendor)
    end

    it 'refuses a role belonging to the store' do
      store_role = create(:role, name: 'Packer', resource: store)

      expect { vendor.add_user(staffer, store_role) }.to raise_error(ArgumentError)
    end

    # Membership on a vendor is not membership of the store's back office.
    it 'does not make its team store staff' do
      vendor.add_user(staffer, create(:role, name: 'Packer', resource: vendor))

      expect(staffer.stores).not_to include(store)
      expect(Spree::Ability.new(staffer, store: store).permission_keys).to be_empty
    end

    # The vendor login refuses anyone this is false for, so a store's own staff
    # cannot mint a vendor token.
    it 'marks its team as vendor members' do
      expect(staffer).not_to be_vendor_member

      vendor.add_user(staffer, create(:role, name: 'Packer', resource: vendor))

      expect(staffer.reload).to be_vendor_member
    end

    it 'does not mark store staff as vendor members' do
      store.add_user(staffer, create(:role, name: 'Support', resource: store))

      expect(staffer.reload).not_to be_vendor_member
    end
  end

  describe 'products' do
    # Every vendor-scoped read is rooted in this association, so a seller from
    # another store would put one store's catalog inside another store's vendor.
    it 'refuses a seller from another store' do
      foreign = create(:vendor, :approved, store: create(:store))

      expect(build(:product, store: store, vendor: foreign)).not_to be_valid
    end

    it 'accepts a seller from the same store' do
      expect(build(:product, store: store, vendor: create(:vendor, :approved, store: store))).to be_valid
    end

    # A product's store is not frozen after create, so the pair can also be
    # broken from the other side — by moving the product and leaving the
    # seller behind.
    it 'refuses moving to a store the seller does not belong to' do
      product = create(:product, store: store, vendor: create(:vendor, :approved, store: store))

      product.store = create(:store)

      expect(product).not_to be_valid
      expect(product.errors[:vendor]).to be_present
    end

    it 'keeps them when the vendor is destroyed' do
      vendor = create(:vendor, :approved)
      product = create(:product, store: store, vendor: vendor)

      vendor.destroy

      expect(product.reload.vendor_id).to be_nil
    end
  end

  describe 'translations' do
    it 'stores a translated name and about per locale' do
      vendor = create(:vendor, name: 'Bright Sparks', about: '<p>We make lamps.</p>')

      Mobility.with_locale(:fr) do
        vendor.update!(name: 'Étincelles', about: '<p>Nous fabriquons des lampes.</p>')
      end

      expect(vendor.reload.name).to eq('Bright Sparks')
      expect(Mobility.with_locale(:fr) { vendor.reload.name }).to eq('Étincelles')
    end

    it 'is registered as a translatable resource' do
      expect(Spree.translatable_resources).to include(described_class)
    end
  end

  describe 'custom fields' do
    # Including the concern is not enough — a resource the registry does not
    # list has no way to define fields for it.
    it 'is registered as a custom-field resource' do
      expect(Spree.custom_fields.enabled_resources).to include(described_class)
    end
  end

  describe 'settlement configuration' do
    it 'defaults to the vendor remitting its own tax' do
      expect(create(:vendor).tax_remittance).to eq('vendor')
    end

    it 'rejects an unknown remittance or interval' do
      expect(build(:vendor, tax_remittance: 'someone_else')).not_to be_valid
      expect(build(:vendor, payouts_schedule_interval: 'fortnightly')).not_to be_valid
    end

    # Nil means "use the store's default", so it stays valid.
    it 'allows both to be unset' do
      expect(build(:vendor, payouts_schedule_interval: nil, minimum_payout_amount: nil)).to be_valid
    end
  end

  describe 'addresses' do
    let(:vendor) { create(:vendor) }

    it 'writes an address from nested attributes' do
      vendor.update!(billing_address: { first_name: 'Ada', last_name: 'Lovelace',
                                        address1: '1 Vendor Way', city: 'London',
                                        postal_code: 'EC1A 1BB', country_code: 'GB', phone: '555' })

      expect(vendor.reload.billing_address.address1).to eq('1 Vendor Way')
    end

    # A vendor is paranoid, so destroy is a soft delete. Taking the addresses
    # with it would hard-delete rows a restored vendor still points at.
    it 'keeps its addresses when soft-deleted, and finds them again on restore' do
      vendor.update!(billing_address: create(:address))
      address_id = vendor.billing_address_id

      vendor.destroy

      expect(Spree::Address.exists?(address_id)).to be(true)
      vendor.restore
      expect(vendor.reload.billing_address_id).to eq(address_id)
    end
  end

  describe 'deletion' do
    let(:vendor) { create(:vendor) }

    # A role refuses deletion while anyone holds it. That guard is for deleting
    # a role on its own; when the whole vendor goes, its team goes with it.
    it 'takes its team with it, so an invited vendor stays deletable' do
      Spree::Vendors::Invite.call(vendor: vendor, email: 'seller@example.com',
                                  inviter: create(:admin_user))

      expect(vendor.destroy).to be_truthy
      expect(Spree::Role.where(resource: vendor)).to be_empty
      expect(Spree::Invitation.where(resource: vendor)).to be_empty
    end
  end
end
