require 'spec_helper'

# Where authorization codes are delivered, and the one registration field a
# merchant must not get wrong.
RSpec.describe 'OAuth redirect URIs' do
  let(:store) { @default_store }

  def build_with(redirect_uri)
    store.oauth_applications.new(name: "Client #{SecureRandom.hex(3)}",
                                 confidential: false, redirect_uri: redirect_uri)
  end

  def authorizable?(redirect_uri)
    ::Doorkeeper::OAuth::PreAuthorization.new(
      ::Doorkeeper.config,
      { client_id: application.uid, response_type: 'code', redirect_uri: redirect_uri,
        scope: 'read_products', code_challenge: 'c' * 43, code_challenge_method: 'S256' },
      create(:admin_user)
    ).authorizable?
  end

  # A plain-http callback hands codes to anyone on the path — except a
  # loopback one, which never leaves the machine. A terminal client listens on
  # a local port and has no certificate for it.
  describe 'the scheme' do
    it 'accepts https' do
      expect(build_with('https://claude.ai/api/mcp/auth_callback')).to be_valid
    end

    it 'accepts a loopback callback over plain http' do
      expect(build_with('http://127.0.0.1/callback')).to be_valid
    end

    it 'accepts a hosted and a loopback callback together' do
      expect(
        build_with("https://claude.ai/api/mcp/auth_callback\nhttp://127.0.0.1/callback")
      ).to be_valid
    end

    it 'refuses plain http anywhere else' do
      expect(build_with('http://example.test/callback')).not_to be_valid
    end

    # Claude Code calls back on `http://localhost:<port>` and never on the IP
    # literal, so it can only be registered by name.
    it 'accepts localhost by name with an explicit port' do
      expect(build_with('http://localhost:3118/callback')).to be_valid
    end

    # Doorkeeper ignores the port only for IP literals, so a port-less
    # `localhost` registration could never be authorized.
    it 'refuses localhost by name without a port' do
      expect(build_with('http://localhost/callback')).not_to be_valid
    end

    it 'refuses localhost on a port no client can listen on' do
      expect(build_with('http://localhost:0/callback')).not_to be_valid
      expect(build_with('http://localhost:65536/callback')).not_to be_valid
    end

    it 'refuses a host that only starts with localhost' do
      expect(build_with('http://localhost.example.test:3118/callback')).not_to be_valid
    end
  end

  # RFC 8252 §7.3: a terminal client picks its port at run time, so the
  # registration cannot name it.
  describe 'a terminal client calling back on an ephemeral port' do
    let(:application) do
      store.oauth_applications.create!(
        name: 'Claude', confidential: false,
        redirect_uri: "https://claude.ai/api/mcp/auth_callback\nhttp://127.0.0.1/callback"
      )
    end

    it 'is authorized whatever port it chose' do
      expect(authorizable?('http://127.0.0.1:49821/callback')).to be(true)
      expect(authorizable?('http://127.0.0.1:60007/callback')).to be(true)
    end

    it 'still refuses a host that was never registered' do
      expect(authorizable?('https://evil.test/callback')).to be(false)
    end
  end

  describe 'a terminal client calling back on localhost' do
    let(:application) do
      store.oauth_applications.create!(
        name: 'Claude Code', confidential: false, redirect_uri: 'http://localhost:3118/callback'
      )
    end

    it 'is authorized on the registered port' do
      expect(authorizable?('http://localhost:3118/callback')).to be(true)
    end

    it 'is refused on any other port' do
      expect(authorizable?('http://localhost:49821/callback')).to be(false)
    end
  end
end
