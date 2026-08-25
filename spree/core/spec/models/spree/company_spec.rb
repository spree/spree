require 'spec_helper'

describe Spree::Company, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }

  describe 'store binding' do
    it 'refuses to move between stores once saved' do
      company = create(:company, store: store)

      company.store = create(:store)

      expect(company).not_to be_valid
    end

    it 'is reachable through the store' do
      company = create(:company, store: store)

      expect(store.companies).to include(company)
      expect(Spree::Company.for_store(store)).to include(company)
    end
  end

  # The former external_id column moved to Spree::ExternalReference so a company
  # can be known to an ERP and a CRM at once (docs/plans/6.0-third-party-pricing-inventory.md).
  describe 'external references' do
    it 'is unique per store and system' do
      create(:company, store: store).set_external_id('erp', 'ACME')
      duplicate = create(:company, store: store)

      expect { duplicate.set_external_id('erp', 'ACME') }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'allows the same reference in another store' do
      create(:company, store: store).set_external_id('erp', 'ACME')
      elsewhere = create(:company, store: create(:store))

      expect(elsewhere.set_external_id('erp', 'ACME')).to be_persisted
    end

    it 'lets several companies carry no reference' do
      create(:company, store: store)

      expect(build(:company, store: store)).to be_valid
    end

    it 'carries one identity per external system' do
      company = create(:company, store: store)
      company.set_external_id('erp', 'ACME')
      company.set_external_id('crm', 'CUST-1')

      expect(company.external_id_for('erp')).to eq('ACME')
      expect(company.external_id_for('crm')).to eq('CUST-1')
    end
  end

  describe 'the tree' do
    let(:root) { create(:company, store: store) }

    it 'defaults a node to the company kind' do
      expect(Spree::Company.new.kind).to eq('company')
    end

    it 'refuses a division at the root' do
      expect(build(:company, store: store, kind: 'division')).not_to be_valid
    end

    it 'accepts a division under a company' do
      expect(build(:company, store: store, kind: 'division', parent: root)).to be_valid
    end

    it 'refuses a parent from another store' do
      foreign = create(:company, store: create(:store))

      expect(build(:company, store: store, parent: foreign)).not_to be_valid
    end

    it 'refuses a cycle' do
      child = create(:company, store: store, parent: root)
      root.parent = child

      expect(root).not_to be_valid
      expect(root.errors[:parent]).to be_present
    end

    it 'refuses to become its own parent' do
      root.parent = root

      expect(root).not_to be_valid
    end

    it 'caps the depth' do
      node = root
      (Spree::Company::MAX_DEPTH - 1).times do
        node = create(:company, store: store, parent: node)
      end

      expect(build(:company, store: store, parent: node)).not_to be_valid
    end

    it 'refuses re-parenting that pushes the subtree past the cap' do
      deep = root
      (Spree::Company::MAX_DEPTH - 2).times do
        deep = create(:company, store: store, parent: deep)
      end
      branch = create(:company, store: store)
      create(:company, store: store, parent: create(:company, store: store, parent: branch))

      branch.parent = deep

      expect(branch).not_to be_valid
      expect(branch.errors[:parent]).to be_present
    end

    it 'walks ancestors leaf to root' do
      child = create(:company, store: store, parent: root)
      grandchild = create(:company, store: store, parent: child)

      expect(grandchild.ancestors).to eq([child, root])
      expect(grandchild.self_and_ancestors).to eq([grandchild, child, root])
      expect(grandchild.root).to eq(root)
    end

    it 'collects the subtree' do
      child = create(:company, store: store, parent: root)
      grandchild = create(:company, store: store, parent: child)
      create(:company, store: store) # unrelated

      expect(root.self_and_descendants).to contain_exactly(root, child, grandchild)
      expect(root.descendants).to contain_exactly(child, grandchild)
    end

    it 'destroys the subtree with the node' do
      child = create(:company, store: store, parent: root)
      create(:company, store: store, parent: child)

      expect { root.destroy }.to change(Spree::Company, :count).by(-3)
    end
  end

  describe '#legal_entity' do
    let(:root) { create(:company, store: store) }

    it 'is the node itself for a company' do
      expect(root.legal_entity).to eq(root)
    end

    it 'is the nearest self-or-ancestor company for a division' do
      division = create(:company, store: store, kind: 'division', parent: root)
      nested = create(:company, store: store, kind: 'division', parent: division)

      expect(nested.legal_entity).to eq(root)
    end

    # A subsidiary never borrows its parent's registration: the walk stops at
    # the first company node whether or not it holds anything.
    it 'stops at the nearest company node' do
      subsidiary = create(:company, store: store, parent: root)
      division = create(:company, store: store, kind: 'division', parent: subsidiary)

      expect(division.legal_entity).to eq(subsidiary)
    end
  end

  describe 'kind changes' do
    it 'refuses turning a registration-holding company into a division' do
      root = create(:company, store: store)
      child = create(:company, store: store, parent: root)
      create(:tax_identifier, owner: child)

      child.kind = 'division'

      expect(child).not_to be_valid
      expect(child.errors[:kind]).to be_present
    end

    # Even without registrations of its own, a company node anchors the
    # divisions below it — demoting it would silently re-resolve their
    # legal_entity to a higher ancestor.
    it 'refuses demoting a company that anchors division children' do
      root = create(:company, store: store)
      child = create(:company, store: store, parent: root)
      create(:company, store: store, kind: 'division', parent: child)

      child.kind = 'division'

      expect(child).not_to be_valid
      expect(child.errors[:kind]).to be_present
    end

    it 'allows demoting a company whose children are all companies' do
      root = create(:company, store: store)
      child = create(:company, store: store, parent: root)
      create(:company, store: store, parent: child)

      child.kind = 'division'

      expect(child).to be_valid
    end
  end

  describe 'default addresses' do
    let(:root) { create(:company, store: store) }
    let(:division) { create(:company, store: store, kind: 'division', parent: root) }

    it 'reads its own default first' do
      own = create(:company_address, company: division, default_billing: true)

      expect(division.default_billing_address).to eq(own.address)
    end

    it 'falls back to the nearest ancestor default' do
      inherited = create(:company_address, company: root, default_shipping: true)

      expect(division.default_shipping_address).to eq(inherited.address)
    end

    it 'is nil when nobody set one' do
      expect(division.default_billing_address).to be_nil
    end
  end

  describe 'metadata' do
    it 'persists to the single metadata column' do
      company = create(:company, store: store, metadata: { 'erp_ref' => 'X-1' })

      expect(company.reload.metadata['erp_ref']).to eq('X-1')
    end
  end

  it 'destroys its memberships, addresses and invitations' do
    company = create(:company, store: store)
    create(:company_membership, company: company)
    create(:company_address, company: company)
    create(:company_invitation, company: company)

    expect { company.destroy }.to change(Spree::CompanyMembership, :count).by(-1).
      and change(Spree::CompanyAddress, :count).by(-1).
      and change(Spree::CompanyInvitation, :count).by(-1)
  end
end
