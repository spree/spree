require 'spec_helper'

# A file the merchant hands over has to reach something. upload_file stores
# it; these are the tools that use the id it returns.
RSpec.describe 'agent tools that consume an upload' do
  let(:store) { @default_store }
  let(:admin) { create(:admin_user) }
  let(:context) do
    Spree::AgentTools::Context.new(store: store, user: admin,
                                   granted_scopes: %w[write_products read_products write_media write_customers],
                                   request_headers: agent_headers_for(admin))
  end

  def tool(name, ctx = context)
    Spree.agent_tools.available_for(ctx).find { |candidate| candidate.tool_name == name }
  end

  # Text as text. A model emits every byte of its arguments, so base64 is
  # only asked for where the bytes are not text — said explicitly rather
  # than sniffed, since some binary happens to be valid UTF-8.
  def upload(filename, bytes, ctx = context)
    tool('upload_file', ctx).call(filename: filename, content: bytes)[:file_id]
  end

  def upload_binary(filename, bytes, ctx = context)
    tool('upload_file', ctx).
      call(filename: filename, content: Base64.strict_encode64(bytes), encoding: 'base64')[:file_id]
  end

  # One transparent pixel. A real PNG, because the type is read from bytes.
  def png
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/AF+AaTqAAAAAElFTkSuQmCC')
  end

  describe 'media_create' do
    let(:product) { create(:product, store: store) }

    it 'places an uploaded file in a product gallery' do
      result = tool('media_create').call(file_id: upload_binary('shot.png', png),
                                         product_id: product.prefixed_id, alt: 'Studio shot')

      expect(result[:error]).to be_nil
      expect(result[:media_type]).to eq('image')

      media = Spree::Media.find_by_prefix_id(result[:id])
      expect(media.viewable).to eq(product)
      expect(media.alt).to eq('Studio shot')
    end

    # A row with no owner is a library file: uploaded, not yet placed.
    it 'leaves it unplaced when no product is named' do
      result = tool('media_create').call(file_id: upload_binary('lib.png', png))

      expect(result[:error]).to be_nil
      expect(Spree::Media.find_by_prefix_id(result[:id]).viewable).to be_nil
    end

    it 'refuses a file id this store did not upload' do
      expect(tool('media_create').call(file_id: 'not-a-signed-id')[:error]).to include('upload_file')
    end

    it 'refuses a product in another store' do
      theirs = create(:product, store: create(:store, code: "other-#{SecureRandom.hex(4)}"))

      expect(tool('media_create').call(file_id: upload_binary('x.png', png), product_id: theirs.prefixed_id)[:error]).
        to include('No product found')
    end

    it 'is withheld from a caller who cannot write media' do
      no_media = Spree::AgentTools::Context.new(store: store, user: admin, granted_scopes: ['read_media'])

      expect(tool('media_create', no_media)).to be_nil
    end
  end

  describe 'create_import' do
    let(:csv) { "sku,name,price\nIMP-1,Imported,24.99\n" }

    # Reading the header row and proposing a mapping is the safe half of the
    # wizard: the merchant sees what the columns were taken to mean before any
    # row is written.
    it 'starts an import and proposes its mapping' do
      result = tool('create_import').call(resource: 'products', file_id: upload('products.csv', csv))

      expect(result[:error]).to be_nil
      expect(result[:status]).to eq('mapping')

      import = Spree::Import.find_by_prefix_id(result[:id])
      expect(import.csv_headers).to eq(%w[sku name price])
      expect(import.mappings).to be_present
    end

    it 'writes no records until the mapping is confirmed' do
      expect { tool('create_import').call(resource: 'products', file_id: upload('products.csv', csv)) }.
        not_to change(Spree::Product, :count)
    end

    # The permission is the write scope of what is being imported, computed
    # per call — a class-level key could not say that, which is why the
    # resource reached the map read-only.
    it 'refuses a kind the grant does not cover' do
      file = upload('products.csv', csv)
      narrowed = Spree::AgentTools::Context.new(store: store, user: admin,
                                                granted_scopes: %w[write_customers write_products])

      # write_products is held, so the tool is offered; write_customers alone
      # is what a customers import would need, and products is refused for a
      # grant that carries neither.
      only_customers = Spree::AgentTools::Context.new(store: store, user: admin,
                                                      granted_scopes: ['write_customers'])

      expect(tool('create_import', narrowed).call(resource: 'products', file_id: file)[:ok]).to be(true)
      expect(tool('create_import', only_customers).call(resource: 'products', file_id: file)[:error]).
        to include('permission to import products')
    end

    it 'names the kinds it can import when given one it cannot' do
      result = tool('create_import').call(resource: 'widgets', file_id: upload('products.csv', csv))

      expect(result[:error]).to include('widgets')
      expect(result[:available]).to include('products', 'customers')
    end

    it 'says so when the file is not CSV at all' do
      result = tool('create_import').call(resource: 'products', file_id: upload_binary('shot.png', png))

      expect(result[:error]).to be_present
      expect(result[:ok]).to be_nil
    end
  end
end
