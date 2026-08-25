require 'spec_helper'

describe Spree::Seller do
  let(:store) { @default_store }

  describe 'statuses' do
    it 'starts pending and moves only through workflows' do
      expect(described_class.default_status).to eq('pending')
      expect(described_class.statuses).to include('approved', 'suspended', 'rejected')
      # A state machine would have generated these; the absence is the point.
      expect(described_class).not_to respond_to(:state_machines)
    end

    it 'generates a predicate and a scope per status' do
      seller = create(:seller, :approved)

      expect(seller).to be_approved
      expect(seller).not_to be_pending
      expect(described_class.approved).to include(seller)
    end

    it 'rejects an unknown status' do
      expect(build(:seller, status: 'flourishing')).not_to be_valid
    end
  end

  describe 'slug' do
    it 'derives from the name when absent' do
      expect(create(:seller, name: 'Bright Sparks Ltd').slug).to eq('bright-sparks-ltd')
    end

    it 'keeps an explicit slug' do
      expect(create(:seller, name: 'Bright Sparks', slug: 'sparks').slug).to eq('sparks')
    end

    it 'is unique within a store' do
      create(:seller, slug: 'sparks', store: store)

      expect(build(:seller, slug: 'sparks', store: store)).not_to be_valid
    end

    it 'may repeat on another store' do
      create(:seller, slug: 'sparks', store: store)

      expect(build(:seller, slug: 'sparks', store: create(:store))).to be_valid
    end
  end

  describe '#sellable?' do
    it 'is true once approved' do
      expect(create(:seller, :approved)).to be_sellable
    end

    it 'is false while unapproved' do
      expect(create(:seller, :onboarding)).not_to be_sellable
    end

    # The catalog stays; what stops is selling.
    it 'is false while on holiday' do
      seller = create(:seller, :on_holiday)

      expect(seller).to be_on_holiday
      expect(seller).not_to be_sellable
      expect(described_class.sellable).not_to include(seller)
    end

    it 'resumes once the holiday has passed' do
      seller = create(:seller, :approved, holiday_mode_until: 1.day.ago)

      expect(seller).not_to be_on_holiday
      expect(described_class.sellable).to include(seller)
    end
  end

  describe 'teams' do
    let(:seller) { create(:seller, :approved) }
    let(:staffer) { create(:admin_user, :without_admin_role) }

    it 'owns its own roles, separate from the store' do
      role = create(:role, name: 'Packer', resource: seller)

      expect(seller.roles).to include(role)
      expect(store.roles).not_to include(role)
    end

    it 'adds a user through a role it owns' do
      seller.add_user(staffer, create(:role, name: 'Packer', resource: seller))

      expect(seller.users).to include(staffer)
      expect(staffer.sellers).to include(seller)
    end

    it 'refuses a role belonging to the store' do
      store_role = create(:role, name: 'Packer', resource: store)

      expect { seller.add_user(staffer, store_role) }.to raise_error(ArgumentError)
    end

    # Membership on a seller is not membership of the store's back office.
    it 'does not make its team store staff' do
      seller.add_user(staffer, create(:role, name: 'Packer', resource: seller))

      expect(staffer.stores).not_to include(store)
      expect(Spree::Ability.new(staffer, store: store).permission_keys).to be_empty
    end

    # The seller login refuses anyone this is false for, so a store's own staff
    # cannot mint a seller token.
    it 'marks its team as seller members' do
      expect(staffer).not_to be_seller_member

      seller.add_user(staffer, create(:role, name: 'Packer', resource: seller))

      expect(staffer.reload).to be_seller_member
    end

    it 'does not mark store staff as seller members' do
      store.add_user(staffer, create(:role, name: 'Support', resource: store))

      expect(staffer.reload).not_to be_seller_member
    end
  end

  describe 'products' do
    # Every seller-scoped read is rooted in this association, so a seller from
    # another store would put one store's catalog inside another store's seller.
    it 'refuses a seller from another store' do
      foreign = create(:seller, :approved, store: create(:store))

      expect(build(:product, store: store, seller: foreign)).not_to be_valid
    end

    it 'accepts a seller from the same store' do
      expect(build(:product, store: store, seller: create(:seller, :approved, store: store))).to be_valid
    end

    # A product's store is not frozen after create, so the pair can also be
    # broken from the other side — by moving the product and leaving the
    # seller behind.
    it 'refuses moving to a store the seller does not belong to' do
      product = create(:product, store: store, seller: create(:seller, :approved, store: store))

      product.store = create(:store)

      expect(product).not_to be_valid
      expect(product.errors[:seller]).to be_present
    end

    it 'keeps them when the seller is destroyed' do
      seller = create(:seller, :approved)
      product = create(:product, store: store, seller: seller)

      seller.destroy

      expect(product.reload.seller_id).to be_nil
    end
  end

  describe 'translations' do
    it 'stores a translated name and about per locale' do
      seller = create(:seller, name: 'Bright Sparks', about: '<p>We make lamps.</p>')

      Mobility.with_locale(:fr) do
        seller.update!(name: 'Étincelles', about: '<p>Nous fabriquons des lampes.</p>')
      end

      expect(seller.reload.name).to eq('Bright Sparks')
      expect(Mobility.with_locale(:fr) { seller.reload.name }).to eq('Étincelles')
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
    it 'defaults to the seller remitting its own tax' do
      expect(create(:seller).tax_remittance).to eq('seller')
    end

    it 'rejects an unknown remittance or interval' do
      expect(build(:seller, tax_remittance: 'someone_else')).not_to be_valid
      expect(build(:seller, payouts_schedule_interval: 'fortnightly')).not_to be_valid
    end

    # Nil means "use the store's default", so it stays valid.
    it 'allows both to be unset' do
      expect(build(:seller, payouts_schedule_interval: nil, minimum_payout_amount: nil)).to be_valid
    end
  end

  describe 'addresses' do
    let(:seller) { create(:seller) }

    it 'writes an address from nested attributes' do
      seller.update!(billing_address: { company: 'Sparks Trading Ltd',
                                        address1: '1 Seller Way', city: 'London',
                                        postal_code: 'EC1A 1BB', country_code: 'GB', phone: '555' })

      expect(seller.reload.billing_address.address1).to eq('1 Seller Way')
    end

    # A commission invoice is addressed to the business, so the company is the
    # part that cannot be left out and a personal name is not asked for.
    it 'requires the company and not a personal name' do
      seller.update!(billing_address: { company: 'Sparks Trading Ltd', address1: '1 Seller Way',
                                        city: 'London', postal_code: 'EC1A 1BB', country_code: 'GB' })

      expect(seller.reload.billing_address.firstname).to be_blank
    end

    it 'refuses a billing address with no company' do
      expect {
        seller.update!(billing_address: { first_name: 'Ada', last_name: 'Lovelace',
                                          address1: '1 Seller Way', city: 'London',
                                          postal_code: 'EC1A 1BB', country_code: 'GB' })
      }.to raise_error(ActiveRecord::RecordInvalid, /company/i)
    end

    # Loaded through the association, so a seller read fresh still gets the
    # business rules — editing one field of a saved address must not fail on a
    # personal name nobody was ever asked for.
    it 'reads a saved billing address back as a business address' do
      seller.update!(billing_address: { company: 'Sparks Trading Ltd', address1: '1 Seller Way',
                                        city: 'London', postal_code: 'EC1A 1BB', country_code: 'GB' })

      reloaded = described_class.find(seller.id)
      expect(reloaded.billing_address.owner).to eq(seller)
      expect(reloaded.billing_address.require_name?).to be(false)
      expect(reloaded.update(billing_address: { city: 'Manchester' })).to be(true)
    end

    # A seller is paranoid, so destroy is a soft delete. Taking the addresses
    # with it would hard-delete rows a restored seller still points at.
    it 'keeps its addresses when soft-deleted, and finds them again on restore' do
      seller.update!(billing_address: Spree::Address.create!(
        owner: seller, company: 'Sparks Trading Ltd', address1: '1 Seller Way',
        city: 'London', zipcode: 'EC1A 1BB', country_code: 'GB'
      ))
      address_id = seller.billing_address_id

      seller.destroy

      expect(Spree::Address.exists?(address_id)).to be(true)
      seller.restore
      expect(seller.reload.billing_address_id).to eq(address_id)
    end
  end

  describe 'deletion' do
    let(:seller) { create(:seller) }

    # A role refuses deletion while anyone holds it. That guard is for deleting
    # a role on its own; when the whole seller goes, its team goes with it.
    it 'takes its team with it, so an invited seller stays deletable' do
      Spree::Sellers::Invite.call(seller: seller, email: 'seller@example.com',
                                  inviter: create(:admin_user))

      expect(seller.destroy).to be_truthy
      expect(Spree::Role.where(resource: seller)).to be_empty
      expect(Spree::Invitation.where(resource: seller)).to be_empty
    end
  end

  describe 'onboarding progress' do
    let(:store) { @default_store }
    let(:seller) { create(:seller, :onboarding, store: store) }

    before { store.seller_requirements.destroy_all }

    it 'reads as finished when the marketplace asks for nothing' do
      expect(seller.onboarding_progress).to eq(done: 0, total: 0)
      expect(seller).to be_onboarding_complete
    end

    it 'counts what is done over what is asked' do
      create(:accept_terms_requirement, store: store)
      create(:billing_address_requirement, store: store)
      seller.update!(terms_accepted_at: Time.current)

      seller.reload
      expect(seller.onboarding_progress).to eq(done: 1, total: 2)
      expect(seller).not_to be_onboarding_complete
    end

    it 'is complete once every required requirement is met, whatever the optional ones say' do
      create(:accept_terms_requirement, store: store, required: true)
      create(:billing_address_requirement, store: store, required: false)
      seller.update!(terms_accepted_at: Time.current)

      seller.reload
      expect(seller).to be_onboarding_complete
      expect(seller.onboarding_progress).to eq(done: 1, total: 2)
    end

    it 'forgets what it computed on reload' do
      create(:accept_terms_requirement, store: store)
      seller.reload
      expect(seller.onboarding_progress).to eq(done: 0, total: 1)

      seller.update!(terms_accepted_at: Time.current)
      seller.reload

      expect(seller.onboarding_progress).to eq(done: 1, total: 1)
    end
  end


  describe '#default_user_role' do
    let(:seller) { create(:seller) }

    # A store's admin role short-circuits through `activate_full_access`; a
    # seller's cannot (`Role#admin?` requires `staff?`), so without seeding the
    # person running the seller would hold nothing at all.
    it 'grants the whole seller vocabulary' do
      expect(seller.default_user_role.permissions).
        to match_array(Spree.permissions.grantable_keys(:seller))
    end

    it 'is immutable, like the store role it mirrors' do
      expect(seller.default_user_role).not_to be_mutable
    end

    it 'returns the same role rather than creating another' do
      first = seller.default_user_role

      expect(seller.default_user_role).to eq(first)
      expect(seller.roles.count).to eq(1)
    end

    # An invitation fills in its own default role, and the operator's invite
    # workflow sends none — so the invitation, not the seller, is what creates
    # the role first. Seeded there too, or whoever accepts holds nothing and
    # every endpoint on their own panel refuses them.
    it 'is seeded even when an invitation creates the role first' do
      invitation = seller.invitations.create!(email: 'hired@example.com', inviter: create(:admin_user))

      expect(invitation.role.permissions).
        to match_array(Spree.permissions.grantable_keys(:seller))
      expect(invitation.role).to eq(seller.default_user_role)
    end

    # The operator's `sellers` key is not in the seller vocabulary, so holding
    # this role never lets a seller administer sellers — their own included.
    it 'does not let its holder manage the seller record' do
      user = create(:admin_user)
      seller.add_user(user)

      ability = Spree::Ability.new(user, resource: seller)

      expect(ability).to be_can(:manage, :seller_profile)
      expect(ability).not_to be_can(:manage, seller)
    end
  end

  describe '#balance' do
    let(:store) { @default_store }
    let(:seller) { create(:seller, :approved, store: store) }

    def earn(amount, currency: 'USD', status: 'completed')
      create(:seller_transfer, seller: seller, currency: currency, amount: amount, status: status,
                               order: create(:order, store: store, seller: seller, currency: currency))
    end

    it 'is what has been earned less what has been settled' do
      earn(40)
      earn(30)
      create(:seller_payout, :completed, seller: seller, amount: 50)

      expect(seller.balance('USD')).to eq(20)
    end

    it 'counts only confirmed earnings' do
      earn(40)
      earn(25, status: 'pending')

      expect(seller.balance('USD')).to eq(40)
    end

    # Nothing is ever converted, so a seller trading in two currencies accrues
    # two balances and is settled in each.
    it 'keeps each currency separate' do
      earn(40)
      earn(30, currency: 'EUR')

      expect(seller.balance('USD')).to eq(40)
      expect(seller.balance('EUR')).to eq(30)
    end

    it 'is nothing for a seller who has earned nothing' do
      expect(seller.balance('USD')).to eq(0)
    end
  end

  describe 'settlement configuration' do
    let(:store) { @default_store }
    let(:seller) { create(:seller, :approved, store: store) }

    it 'falls back to the store’s schedule and threshold' do
      expect(seller.resolved_payouts_schedule_interval).to eq('monthly')
      expect(seller.resolved_minimum_payout_amount).to eq(0)
    end

    it 'prefers its own once it deviates' do
      seller.update!(payouts_schedule_interval: 'weekly', minimum_payout_amount: 25)

      expect(seller.resolved_payouts_schedule_interval).to eq('weekly')
      expect(seller.resolved_minimum_payout_amount).to eq(25)
    end
  end
  # The seller's identity in the system that pays them — recorded where every
  # other external identity is, rather than in a column of its own.
  describe 'the payout account' do
    let(:seller) { create(:seller, :approved, store: @default_store) }

    # A stand-in for a provider gem, which names itself when it files the
    # account it minted.
    let(:provider) do
      Class.new(Spree::PayoutProvider::Base) do
        def self.reference_system = 'acme_pay'
      end
    end

    it 'is filed under the provider that issued it' do
      seller.set_payout_account_reference(provider, 'acct_123')

      reference = seller.external_references.reload.first
      expect(reference.system).to eq('acme_pay')
      expect(reference.external_id).to eq('acct_123')
    end

    it 'reads back what was written' do
      seller.set_payout_account_reference(provider, 'acct_123')

      expect(seller.reload.payout_account_reference(provider)).to eq('acct_123')
    end

    it 'is nil for a seller who holds no account' do
      expect(seller.payout_account_reference(provider)).to be_nil
    end

    it 'forgets the account when blanked' do
      seller.set_payout_account_reference(provider, 'acct_123')
      seller.set_payout_account_reference(provider, nil)

      expect(seller.reload.payout_account_reference(provider)).to be_nil
    end

    # The whole point of keying by provider: a marketplace that changes
    # provider keeps the old account rather than reading it as the new one.
    it 'keeps one provider’s account out of another’s' do
      other_provider = Class.new(Spree::PayoutProvider::Base) do
        def self.reference_system = 'other_pay'
      end
      seller.set_payout_account_reference(provider, 'acct_123')

      expect(seller.reload.payout_account_reference(other_provider)).to be_nil
    end

    # What a provider webhook does: it knows the account, not the seller.
    it 'finds the seller an account belongs to' do
      seller.set_payout_account_reference(provider, 'acct_123')

      expect(Spree::Seller.with_payout_account(@default_store, provider, 'acct_123')).to contain_exactly(seller)
    end

    it 'does not find a seller in another marketplace' do
      seller.set_payout_account_reference(provider, 'acct_123')

      expect(Spree::Seller.with_payout_account(create(:store), provider, 'acct_123')).to be_empty
    end
  end
end
