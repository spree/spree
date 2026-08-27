require 'spec_helper'

RSpec.describe Spree::Export, :job, type: :model do
  it_behaves_like 'lifecycle events', factory: :product_export

  let(:store) { @default_store }
  let(:user) { create(:admin_user) }

  let(:search_params) { nil }
  let(:export) { build(:product_export, store: store, user: user, format: 'csv', search_params: search_params) }

  describe '#model_class' do
    it 'returns the correct record class' do
      expect(export.model_class).to eq(Spree::Product)
    end
  end

  describe '.required_scope' do
    it 'derives the scope family from the class name' do
      expect(Spree::Exports::Products.required_scope).to eq(:products)
      expect(Spree::Exports::Customers.required_scope).to eq(:customers)
      expect(Spree::Exports::GiftCards.required_scope).to eq(:gift_cards)
    end

    it 'honors subclass overrides where the data is gated by a different scope' do
      expect(Spree::Exports::CouponCodes.required_scope).to eq(:promotions)
      expect(Spree::Exports::NewsletterSubscribers.required_scope).to eq(:customers)
      expect(Spree::Exports::ProductTranslations.required_scope).to eq(:products)
    end

    it 'returns nil on the base class (fail closed — *_all keys only)' do
      expect(Spree::Export.required_scope).to be_nil
    end
  end

  describe '#export_file_name' do
    before { export.save! }

    it 'returns the correct file name' do
      expect(export.export_file_name).to match(/products-#{export.store.code}-\d{8}\d{6}\.csv/)
    end
  end

  describe '#generate' do
    it 'generates the export' do
      export.save!
      expect { export.generate }.to change(export.attachment, :attached?).from(false).to(true)

      expect(export.attachment.content_type).to eq('text/csv')
    end

    it 'sends the export done email' do
      export.save!
      expect { export.generate }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    context 'when the export has no user (created via secret API key)' do
      let(:export) { build(:product_export, store: store, user: nil, format: 'csv') }

      it 'still generates and attaches the CSV' do
        export.save!
        expect { export.generate }.to change(export.attachment, :attached?).from(false).to(true)
      end

      it 'does not enqueue the export done email' do
        export.save!
        expect { export.generate }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end

    context 'when the export type is Spree::Exports::Customers' do
      let(:export) { build(:customer_export, store: store, user: user, format: 'csv') }

      it 'generates the export' do
        export.save!
        expect { export.generate }.to change(export.attachment, :attached?).from(false).to(true)
      end
    end
  end

  describe '#scope' do
    let(:seller) { create(:seller, :approved, store: store) }
    let(:other_seller) { create(:seller, :approved, store: store) }

    context 'when the export belongs to a seller' do
      let(:export) { build(:order_export, store: store, seller: seller, user: nil) }

      let!(:mine) { create(:completed_order_with_totals, store: store, seller: seller) }
      let!(:theirs) { create(:completed_order_with_totals, store: store, seller: other_seller) }

      it "narrows to that seller's own records" do
        expect(export.scope).to include(mine)
        expect(export.scope).not_to include(theirs)
      end

      it 'leaves out drafts' do
        draft = create(:order, store: store, seller: seller, status: 'draft', cart: nil)

        expect(export.scope).not_to include(draft)
      end

      # The ability grants the model class, never a subset, so a seller export
      # of something with no `for_seller` would quietly span the marketplace.
      it 'refuses a model it cannot narrow' do
        export = build(:customer_export, store: store, seller: seller, user: nil)

        expect { export.scope }.to raise_error(Spree::Export::SellerScopeUnavailable)
      end

      # Caught at create so the caller reads a 422, rather than in the job
      # where the raise goes unrecorded and the export never becomes `done`.
      it 'is refused before it can be queued' do
        export = build(:customer_export, store: store, seller: seller, user: nil)

        expect(export).not_to be_valid
        expect(export.errors[:type]).to be_present
      end

      it 'allows a model it can narrow' do
        expect(build(:order_export, store: store, seller: seller, user: nil)).to be_valid
        expect(build(:product_export, store: store, seller: seller, user: nil)).to be_valid
      end
    end

    context 'when the export has no seller' do
      let(:export) { build(:order_export, store: store, user: nil) }

      let!(:sellers_order) { create(:completed_order_with_totals, store: store, seller: seller) }

      it 'spans the store' do
        expect(export.scope).to include(sellers_order)
      end
    end
  end

  # The buyer's email is withheld from every seller-facing surface; a bulk CSV
  # is the one most likely to leave the building.
  describe 'a seller export of orders' do
    let(:seller) { create(:seller, :approved, store: store) }
    let!(:order) { create(:completed_order_with_totals, store: store, seller: seller) }

    let(:seller_export) { create(:order_export, store: store, seller: seller, user: nil) }
    let(:operator_export) { create(:order_export, store: store, user: nil) }

    def rows_for(export)
      export.generate
      ::CSV.parse(export.attachment.download, headers: true)
    end

    it 'leaves the buyer email out of the headers' do
      expect(seller_export.csv_headers).not_to include('Email')
    end

    it "does not write the buyer's email anywhere in the file" do
      seller_export.generate

      expect(seller_export.attachment.download).not_to include(order.email)
    end

    # The row and the header list are filtered separately, so a mismatch would
    # shift every later value into the wrong column while still looking valid.
    it 'keeps the remaining columns aligned with their headers' do
      row = rows_for(seller_export).first

      expect(row['Number']).to eq(order.number)
      expect(row['Shipping Name']).to eq(order.ship_address.full_name)
      expect(row['Billing Name']).to eq(order.bill_address.full_name)
    end

    it 'still gives the seller the addresses they ship and invoice against' do
      headers = seller_export.csv_headers

      expect(headers).to include('Shipping Address 1', 'Shipping Phone')
      expect(headers).to include('Billing Address 1')
      expect(headers).to include('Notes')
    end

    it "leaves the operator's own export untouched" do
      expect(operator_export.csv_headers).to include('Email')
      expect(rows_for(operator_export).first['Email']).to eq(order.email)
    end
  end

  describe '#records_to_export' do
    let!(:matching_products) { create_list(:product, 3, name: 'test') }
    let!(:non_matching_products) { create_list(:product, 3, name: 'something else') }

    context 'without search params' do
      it 'returns all products' do
        expect(export.records_to_export).to match_array(store.products)
      end
    end

    context 'with search params' do
      let(:search_params) { { name_cont: 'test' }.to_json }

      it 'returns matching products' do
        expect(export.records_to_export).to match_array(matching_products)
        expect(export.records_to_export.count).to eq(matching_products.count)
      end
    end

    context 'with a prefixed-id filter' do
      let(:target) { matching_products.first }
      let(:search_params) { { id_eq: target.prefixed_id }.to_json }

      it 'decodes prefixed IDs before handing to Ransack' do
        expect(export.records_to_export).to contain_exactly(target)
      end
    end

    context 'with a prefixed-id array filter' do
      let(:targets) { matching_products.first(2) }
      let(:search_params) { { id_in: targets.map(&:prefixed_id) }.to_json }

      it 'decodes each value' do
        expect(export.records_to_export).to match_array(targets)
      end
    end

    # The dashboard builds export search_params from the same filter state as
    # the products table, so a `cf_*` filter has to survive the round-trip —
    # Ransack alone has no such attribute.
    context 'with a custom field filter' do
      let!(:definition) do
        create(:custom_field_definition, :short_text_field, :searchable, namespace: 'custom', key: 'material')
      end
      let(:target) { matching_products.first }
      let(:search_params) { { cf_custom_material_i_cont: 'wool' }.to_json }

      before { target.set_custom_field(definition, 'Wool-Blend') }

      it 'applies the custom field predicate' do
        expect(export.records_to_export).to contain_exactly(target)
      end
    end
  end

  describe '#send_export_done_email' do
    before { export.save! }

    it 'queues the export done email' do
      expect { export.send_export_done_email }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    context 'when the export has no user' do
      let(:export) { build(:product_export, store: store, user: nil, format: 'csv') }

      it 'does not queue an email — apps polling via secret API key have no inbox' do
        expect { export.send_export_done_email }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end
    end
  end

  describe 'CSV formula injection' do
    let(:export) { build(:customer_export, store: store, user: user, format: 'csv') }

    let!(:malicious_customer) do
      create(:user,
             first_name: '=HYPERLINK("https://evil.example","Click")',
             last_name: '+1-555-EVIL',
             email: 'mallory@example.com')
    end

    it 'prefixes cells starting with formula triggers when the export runs' do
      export.save!
      export.generate

      rows = ::CSV.parse(export.attachment.download)
      malicious_row = rows.find { |r| r[2] == 'mallory@example.com' }

      expect(malicious_row).not_to be_nil
      expect(malicious_row[0]).to eq('\'=HYPERLINK("https://evil.example","Click")')
      expect(malicious_row[1]).to eq("'+1-555-EVIL")
    end
  end

  describe '#normalize_search_params' do
    let(:export) { build(:export) }

    context 'with nil search_params' do
      it 'does nothing' do
        export.search_params = nil
        expect { export.normalize_search_params }.not_to change(export, :search_params)
      end
    end

    context 'with empty search_params' do
      it 'does nothing' do
        export.search_params = ''
        expect { export.normalize_search_params }.not_to change(export, :search_params)
      end
    end

    context 'with valid JSON string' do
      let(:params) { { filters: { date: '2023-01-01' } }.to_json }

      it 'maintains the same content' do
        export.search_params = params
        export.normalize_search_params
        expect(JSON.parse(export.search_params)).to eq(JSON.parse(params))
      end

      it 'ensures valid JSON output' do
        export.search_params = params
        export.normalize_search_params
        expect { JSON.parse(export.search_params) }.not_to raise_error
      end
    end

    context 'with invalid JSON string' do
      it 'preserves the original string' do
        export.search_params = '{invalid: json'
        expect { export.normalize_search_params }.not_to raise_error
        expect(export.search_params).to eq('{invalid: json')
      end
    end

    context 'with Ruby hash input' do
      it 'converts to JSON string' do
        export.search_params = { key: 'value' }
        export.normalize_search_params
        expect(export.search_params).to eq('{"key":"value"}')
      end
    end

    context 'with pre-normalized params' do
      it 'does not double-process' do
        export.search_params = { date: Time.current }.to_json
        original = export.search_params.dup
        export.normalize_search_params
        expect(export.search_params).to eq(original)
      end
    end
  end
end
