require 'spec_helper'

# The dashboard uploads in two steps — presign, then PUT. An agent has only
# its arguments, so the file arrives base64 and is stored in one call.
RSpec.describe 'agent file upload' do
  let(:store) { @default_store }
  let(:api_key) { create(:api_key, :secret, store: store, scopes: ['write_all']) }
  let(:context) { Spree::AgentTools::Context.new(store: store, api_key: api_key, request_headers: agent_headers_for_key(api_key)) }

  def tool(ctx = context)
    Spree.agent_tools.available_for(ctx).find { |candidate| candidate.tool_name == 'upload_file' }
  end

  # Text as text, which is the default now: a model has to emit every byte
  # of a tool call's arguments, and base64 is a third larger again.
  def upload(filename, bytes, **extra)
    tool.call(filename: filename, content: bytes, **extra)
  end

  def upload_binary(filename, bytes, **extra)
    tool.call(filename: filename, content: Base64.strict_encode64(bytes), encoding: 'base64', **extra)
  end

  describe 'storing a file' do
    it 'answers with an id other writes accept' do
      result = upload('products.csv', "sku,name\nA-1,Thing\n")

      expect(result[:error]).to be_nil
      expect(result[:content_type]).to eq('text/csv')
      expect(result[:filename]).to eq('products.csv')
      expect(result[:file_id]).to be_present
    end

    # The whole point of the tool: the id has to be the one ActiveStorage
    # hands a browser, or nothing downstream can use it.
    it 'produces an id an import attaches and reads back' do
      csv = "sku,name\nA-1,Thing\n"
      import = Spree::Imports::Products.new(store: store, user: create(:admin_user))

      import.attachment = upload('products.csv', csv)[:file_id]

      expect(import.save).to be(true)
      expect(import.reload.attachment.download).to eq(csv)
    end

    it 'accepts base64 a model wrapped in newlines' do
      result = tool.call(filename: 'shot.png', content: Base64.encode64("\x89PNG\r\n\x1a\n#{"\0" * 40}"),
                         encoding: 'base64')

      expect(result[:ok]).to be(true)
    end
  end

  describe 'what it refuses' do
    # `Base64.decode64` cannot be the test — it skips what it does not
    # recognise, so prose decoded to a few bytes and the refusal talked about
    # content types instead of encoding.
    it 'refuses content that is not base64 at all' do
      expect(tool.call(filename: 'a.csv', content: '!!!not base64!!!', encoding: 'base64')[:error])
        .to include('base64')
    end

    it 'refuses an empty file' do
      expect(upload('a.csv', '')[:error]).to be_present
    end

    # The type is read from the bytes, so renaming a file does not smuggle it
    # past — the same reason the attachment validators look at content.
    it 'refuses a file whose bytes are not a kind it stores' do
      result = upload('harmless.csv', "<html><script>alert(1)</script></html>")

      # The endpoint's allowlist, in its own words.
      expect(result[:error]).to include('text/html')
    end

    it 'refuses an executable however it is named' do
      expect(upload('data.csv', "#!/bin/sh\nrm -rf /\n")[:error]).to include('not accepted')
    end

    it 'refuses a file beyond the cap' do
      stub_const('Spree::Api::V3::Admin::DirectUploadsController::MAX_UPLOAD_BYTES', 16)

      expect(upload('big.csv', 'x' * 64)[:error]).to include('must be under')
    end

    it 'is withheld from a caller who cannot write' do
      read_only = create(:api_key, :secret, store: store, scopes: ['read_products'])

      expect(tool(Spree::AgentTools::Context.new(store: store, api_key: read_only, request_headers: agent_headers_for_key(read_only)))).to be_nil
    end
  end

  # A stored file is inert until a later write uses it, and that write carries
  # its own permission — so uploading is not a way to reach anything.
  describe 'what storing one does not do' do
    it 'attaches the file to nothing by itself' do
      expect { upload('products.csv', "sku,name\nA-1,Thing\n") }.
        not_to change(Spree::Import, :count)
    end
  end
end
