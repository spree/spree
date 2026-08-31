# Behavior of Spree::Purchase::PurchaseOrder, run against both hosts — the
# buyer's reference has to mean the same thing on the cart they fill in and on
# the order it becomes.
#
# @param factory [Symbol] the host's factory (:cart or :order)
shared_examples_for 'a purchase carrying a PO reference' do |factory:|
  subject(:purchase) { FactoryBot.create(factory) }

  describe '#po_number' do
    it 'strips surrounding whitespace a buyer pasted in' do
      purchase.update!(po_number: "  PO-4471\n")

      expect(purchase.reload.po_number).to eq('PO-4471')
    end

    it 'stores a blank reference as nothing rather than an empty string' do
      purchase.update!(po_number: '   ')

      expect(purchase.reload.po_number).to be_nil
    end
  end

  describe '#po_number_required?' do
    it 'is false without a company' do
      expect(purchase.po_number_required?).to be(false)
    end

    context 'with a company that demands one' do
      let(:company) do
        FactoryBot.create(:company, store: purchase.store, po_number_required: true)
      end

      before { purchase.update_column(:company_id, company.id) }

      it 'is true' do
        expect(purchase.reload.po_number_required?).to be(true)
      end
    end

    context 'with a company that does not' do
      let(:company) { FactoryBot.create(:company, store: purchase.store) }

      before { purchase.update_column(:company_id, company.id) }

      it 'is false' do
        expect(purchase.reload.po_number_required?).to be(false)
      end
    end
  end

  describe '#po_document' do
    it 'accepts a PDF' do
      purchase.po_document.attach(
        io: StringIO.new('%PDF-1.4 purchase order'),
        filename: 'po.pdf',
        content_type: 'application/pdf'
      )

      expect(purchase).to be_valid
      expect(purchase.po_document).to be_attached
    end

    # The validation library raises its own install text when `file` is
    # missing. That text must never become the API message — a buyer cannot
    # install a system package.
    it 'does not leak a missing file-command error to the buyer' do
      allow(Open3).to receive(:capture2).with('file', any_args).and_raise(Errno::ENOENT)

      purchase.po_document.attach(
        io: StringIO.new('%PDF-1.4 purchase order'),
        filename: 'po.pdf',
        content_type: 'application/pdf'
      )

      expect(purchase).not_to be_valid
      expect(purchase.errors.full_messages.join).to include(Spree.t(:attachment_could_not_be_verified))
      expect(purchase.errors.full_messages.join).not_to include('file command-line tool')
    end

    # Spoofing protection is the point: the bytes decide, not the header the
    # uploader sent.
    it 'refuses an executable dressed up as a PDF' do
      purchase.po_document.attach(
        io: StringIO.new("#!/bin/sh\nrm -rf /"),
        filename: 'po.pdf',
        content_type: 'application/pdf'
      )

      expect(purchase).not_to be_valid
      expect(purchase.errors[:po_document]).to be_present
    end

    it 'refuses a file over the size cap' do
      oversized = 'a' * (Spree::Purchase::PurchaseOrder::MAX_PO_DOCUMENT_SIZE + 1)
      purchase.po_document.attach(
        io: StringIO.new(oversized), filename: 'po.pdf', content_type: 'application/pdf'
      )

      expect(purchase).not_to be_valid
      expect(purchase.errors[:po_document]).to be_present
    end

    # A direct upload declares its size before sending any bytes, so the
    # recorded byte_size is the uploader's claim, not a measurement. Trusting
    # it would let an under-declared file past every size check.
    it 'refuses a file whose stored bytes exceed the cap despite a small declared size' do
      oversized = 'a' * (Spree::Purchase::PurchaseOrder::MAX_PO_DOCUMENT_SIZE + 1024)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(oversized), filename: 'po.pdf', content_type: 'application/pdf',
        service_name: Spree.private_storage_service_name
      )
      blob.update_column(:byte_size, 5)

      purchase.po_document.attach(blob)

      expect(purchase).not_to be_valid
      expect(purchase.errors[:po_document].join).to include('larger than')
    end

    it 'is stored privately' do
      purchase.po_document.attach(
        io: StringIO.new('%PDF-1.4'), filename: 'po.pdf', content_type: 'application/pdf'
      )

      expect(purchase.po_document.blob.service_name).to eq(Spree.private_storage_service_name.to_s)
    end
  end
end
