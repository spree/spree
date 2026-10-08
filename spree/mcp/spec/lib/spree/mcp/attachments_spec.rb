require 'spec_helper'

RSpec.describe Spree::Mcp::Attachments do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }

  def context_for(scopes)
    Spree::AgentTools::Context.new(store: store, user: user, granted_scopes: scopes)
  end

  def order_with_po(store: @default_store, po_number: 'PO-4471')
    create(:order, store: store).tap do |order|
      order.po_number = po_number
      order.po_document.attach(io: StringIO.new("%PDF-1.4\ntrailer<<>>\n%%EOF\n"),
                               filename: 'buyer-po.pdf', content_type: 'application/pdf')
      order.save(validate: false)
    end
  end

  describe 'what the registry decides' do
    # The point of the registry: one registration serves any resource, and a
    # file nobody registered is not reachable however it is addressed.
    it 'offers a registered attachment' do
      order = order_with_po

      resource = described_class.list(context_for(['read_orders'])).first

      expect(resource[:uri]).to eq("spree+file://orders/#{order.prefixed_id}")
      expect(resource[:name]).to eq('buyer-po.pdf')
      expect(resource[:title]).to eq("Purchase order for #{order.number}")
      expect(resource[:mimeType]).to eq('application/pdf')
    end

    # A subject access export is one customer's entire personal data, and a
    # digital asset is the product someone paid for. Neither is registered,
    # and naming one directly must not reach it.
    it 'cannot reach an attachment nobody registered' do
      expect(Spree.agent_attachments.find('data_requests')).to be_nil
      expect(Spree.agent_attachments.find('digital_assets')).to be_nil

      contents = described_class.read(context_for(['read_all']), 'spree+file://data_requests/dr_whatever')

      expect(contents).to be_nil
    end

    it 'leaves out a record carrying no file' do
      order_with_po
      create(:order, store: store)

      expect(described_class.list(context_for(['read_orders'])).size).to eq(1)
    end
  end

  # The registry says which files exist; the resource map says who may read
  # them. Keeping the two apart is what stops a file becoming a way around a
  # permission the merchant withheld.
  describe 'the permission a file rides' do
    it 'is the one its own resource declares' do
      entry = Spree.agent_attachments.find('orders')

      expect(entry.resource_entry.permission).to eq('read_orders')
      expect(entry.readable_by?(context_for(['read_orders']))).to be(true)
      expect(entry.readable_by?(context_for(['read_products']))).to be(false)
    end
  end

  describe 'what a grant may see' do
    before { order_with_po }

    # Each file rides its own record's permission, so one grant never opens
    # another resource's paperwork.
    it 'offers nothing for a resource the grant cannot read' do
      expect(described_class.list(context_for(['read_products']))).to be_empty
    end

    it 'refuses to read one the grant cannot reach' do
      order = Spree::Order.last

      expect(described_class.read(context_for(['read_products']), "spree+file://orders/#{order.prefixed_id}")).to be_nil
    end
  end

  describe 'reading one' do
    let!(:order) { order_with_po }
    let(:uri) { "spree+file://orders/#{order.prefixed_id}" }

    # Handed over as bytes rather than extracted text: the model already
    # understands PDFs and images, and converting first would lose the layout
    # a document carries its meaning in.
    it 'returns the file itself, base64 encoded' do
      content = described_class.read(context_for(['read_orders']), uri).first

      expect(content[:mimeType]).to eq('application/pdf')
      expect(Base64.strict_decode64(content[:blob])).to start_with('%PDF')
    end

    # Another store's file is indistinguishable from one that does not exist,
    # so a probe learns nothing either way.
    it 'cannot reach a file belonging to another store' do
      theirs = order_with_po(store: create(:store, code: "other-#{SecureRandom.hex(4)}"), po_number: 'PO-THEIRS')

      expect(described_class.read(context_for(['read_orders']), "spree+file://orders/#{theirs.prefixed_id}")).to be_nil
    end

    it 'answers nothing for a uri naming no record' do
      expect(described_class.read(context_for(['read_orders']), 'spree+file://orders/or_nonsense')).to be_nil
    end

    it 'answers nothing for a malformed uri' do
      expect(described_class.read(context_for(['read_orders']), 'spree+file://orders')).to be_nil
    end

    # Base64 adds a third again on the wire and the body is read into memory
    # to send it, so a large file is named and sized rather than inlined.
    it 'declines to inline a file beyond the cap' do
      stub_const("#{described_class}::MAX_INLINE_BYTES", 8)

      content = described_class.read(context_for(['read_orders']), uri).first

      expect(content[:blob]).to be_nil
      expect(content[:text]).to include('too large')
    end
  end
end
