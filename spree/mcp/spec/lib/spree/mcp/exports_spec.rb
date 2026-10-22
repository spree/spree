require 'spec_helper'

RSpec.describe Spree::Mcp::Exports do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }

  # Reading an export now goes through the Admin API's own endpoints, so the
  # context carries the credential a real request would.
  def context_for(scopes)
    key = create(:api_key, :secret, store: store, scopes: scopes)

    Spree::AgentTools::Context.new(
      store: store, api_key: key, granted_scopes: scopes,
      request_headers: { 'HTTP_X_SPREE_API_KEY' => key.plaintext_token, 'HTTP_HOST' => 'www.example.com' }
    )
  end

  def finished_export(klass, store: @default_store)
    klass.create!(store: store, user: user, format: 'csv').tap do |export|
      export.attachment.attach(io: StringIO.new("id,name\n1,Thing\n"),
                               filename: 'export.csv', content_type: 'text/csv')
    end
  end

  # Reading an export costs what reading the records costs. Otherwise a file
  # becomes the way around a scope the merchant deliberately withheld.
  describe 'what a grant may see' do
    before do
      finished_export(Spree::Exports::Products)
      finished_export(Spree::Exports::Orders)
    end

    it 'offers only the exports the grant covers' do
      titles = described_class.list(context_for(['read_orders'])).map { |r| r[:title] }

      expect(titles).to all(include('Orders'))
      expect(titles.join).not_to include('Products')
    end

    it 'refuses to read one the grant does not cover' do
      products = Spree::Exports::Products.last

      expect(described_class.read(context_for(['read_orders']),
                                  "spree+export://#{products.prefixed_id}")).to be_nil
    end

    # The id lands in a path, so one carrying a `/` would address another
    # route under the export rather than the export itself.
    it 'refuses an id that is not a single path segment' do
      products = Spree::Exports::Products.last

      expect(described_class.read(context_for(['read_all']),
                                  "spree+export://#{products.prefixed_id}/download")).to be_nil
    end
  end

  # A gift card export that already exists — made in the dashboard, or by an
  # earlier version — must still not be readable here. Refusing only at
  # creation would leave every file already on disk collectable.
  describe 'an export whose rows carry a bearer instrument' do
    it 'refuses to read it, whatever the grant holds' do
      export = finished_export(Spree::Exports::GiftCards)

      result = described_class.read(context_for(['read_all']),
                                    "spree+export://#{export.prefixed_id}")

      expect(result.first[:text]).to include('spend money')
      expect(result.first[:text]).not_to include('Thing')
    end
  end

  describe 'another store' do
    let(:other_store) { create(:store, code: "other-#{SecureRandom.hex(4)}") }

    it 'cannot see or read this store\'s exports' do
      export = finished_export(Spree::Exports::Products)
      elsewhere = Spree::AgentTools::Context.new(store: other_store, user: user,
                                                 granted_scopes: ['read_all'])

      expect(described_class.list(elsewhere)).to be_empty
      expect(described_class.read(elsewhere, "spree+export://#{export.prefixed_id}")).to be_nil
    end
  end

  # An unfinished export has no file, and naming it would send the model after
  # something it cannot read.
  it 'leaves out an export that has not finished' do
    Spree::Exports::Products.create!(store: store, user: user, format: 'csv')

    expect(described_class.list(context_for(['read_all']))).to be_empty
  end

  # Past a point the body is not something a model can usefully read, and
  # returning it would push out the conversation that asked for it.
  it 'describes a file too large to return instead of returning it' do
    export = finished_export(Spree::Exports::Products)
    # The size comes from what the endpoint reports, so the cap is what has
    # to move — the file itself is a fixture of a few bytes.
    stub_const("#{described_class}::MAX_INLINE_BYTES", 1)

    contents = described_class.read(context_for(['read_all']), "spree+export://#{export.prefixed_id}")

    expect(contents.first[:mimeType]).to eq('text/plain')
    expect(contents.first[:text]).to include('too large')
  end
end
