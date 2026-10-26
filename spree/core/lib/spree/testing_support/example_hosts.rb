require 'resolv'

# Hosts under example.com, the domain reserved for documentation, resolve to a
# fixed public address, so a spec that saves a webhook endpoint at one needs
# no live DNS. Every other host still resolves for real.
RSpec.configure do |config|
  config.before do
    # Through RSpec::Mocks directly: a spec may define its own `receive` or `allow`.
    resolve = Resolv.method(:getaddresses)
    RSpec::Mocks.allow_message(Resolv, :getaddresses) do |name|
      name.to_s.match?(/\A(?:[^.]+\.)*example\.com\z/i) ? ['93.184.215.14'] : resolve.call(name)
    end
  end
end
