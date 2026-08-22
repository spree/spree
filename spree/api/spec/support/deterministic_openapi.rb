# frozen_string_literal: true

# The OpenAPI specs in docs/api-reference/ embed real response bodies captured
# while the integration suite runs, so anything the suite generates at random
# lands in a checked-in file. Two runs of unchanged code used to produce a
# ~1,800 line diff, which buried real API changes in noise during review.
#
# Under OPENAPI=true (set by the swaggerize rake task) every source of that
# noise is pinned, so regenerating the specs yields a byte-identical file
# unless the API itself changed. Nothing here is loaded by a normal spec run —
# the suite keeps its random names and real clock.
if ENV['OPENAPI'] == 'true'
  require 'timecop'
  require 'securerandom'
  require 'digest/md5'
  require 'ffaker'

  module Spree
    module OpenAPIDeterminism
      # The instant every generated example is stamped with. Anything derived
      # from it — an expiry fourteen days out, a promotion window — lands on a
      # stable value too, so a whole run reduces to this one timestamp. Bump it
      # only when the dates in the published examples start looking stale; each
      # bump rewrites every timestamp in the checked-in specs.
      FROZEN_TIME = Time.utc(2026, 1, 15, 12, 0, 0)

      # Base seed for the two pseudo-random generators in play: Ruby's global
      # one, which Kernel.rand draws from, and FFaker's own, which is separate
      # and needs seeding through its own API. Both are mixed with the example's
      # identity for the same reason the token seeds are: a run-wide constant
      # would hand every example the same "random" name and email, and the
      # unique ones then collide on a real index.
      RANDOM_SEED = 20_260_115

      # Signing secret for the JWTs shown in the examples. It signs nothing
      # real — these tokens are documentation, generated against a throwaway
      # dummy app — but it has to be the same everywhere for the signatures
      # to match across machines.
      JWT_SECRET = 'openapi-example-signing-secret'

      # SecureRandom bypasses the global PRNG (it reads from the OS), so seeding
      # alone leaves API keys, invitation tokens and JWT ids churning. These
      # counter-backed replacements produce values with the right shape and
      # length for anything that stores or displays them.
      module PredictableSecureRandom
        HEX_ALPHABET = '0123456789abcdef'
        BASE58_ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
        BASE36_ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyz'
        URL_SAFE_ALPHABET = "#{BASE36_ALPHABET}ABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

        class << self
          # Values must be unique across the whole run (they back columns with
          # unique indexes, such as a store's setup token) while still being
          # reproducible. Deriving the seed from the current example's id plus a
          # per-example counter gives both: unique because no two examples share
          # an id, reproducible because an example's id does not change between
          # runs, and stable under edits because adding one spec cannot shift
          # the values another spec produces.
          def scope!(example_key)
            @example_key = example_key
            @sequence = 0
          end

          # Digest rather than String#hash: Ruby randomizes String#hash per
          # process, which is exactly the churn this file exists to remove.
          def next_seed
            @sequence = (@sequence || 0) + 1
            Digest::MD5.hexdigest("#{@example_key}/#{@sequence}")[0, 15].to_i(16)
          end

          def string_from(alphabet, length)
            generator = Random.new(next_seed)
            Array.new(length) { alphabet[generator.rand(alphabet.length)] }.join
          end
        end

        # Callers pass nil to mean "the default length", so every override
        # normalizes it rather than doing arithmetic on it.
        def hex(length = nil)
          PredictableSecureRandom.string_from(HEX_ALPHABET, (length || 16) * 2)
        end

        def base58(length = nil)
          PredictableSecureRandom.string_from(BASE58_ALPHABET, length || 16)
        end

        def base36(length = nil)
          PredictableSecureRandom.string_from(BASE36_ALPHABET, length || 16)
        end

        def alphanumeric(length = nil, chars: nil)
          return super if chars

          PredictableSecureRandom.string_from(BASE58_ALPHABET, length || 16)
        end

        def urlsafe_base64(length = nil, _padding = false)
          PredictableSecureRandom.string_from(URL_SAFE_ALPHABET, ((length || 16) * 4 / 3.0).ceil)
        end

        def uuid
          digits = PredictableSecureRandom.string_from(HEX_ALPHABET, 32)
          [digits[0, 8], digits[8, 4], "4#{digits[13, 3]}", "a#{digits[17, 3]}", digits[20, 12]].join('-')
        end

        def bytes(length)
          PredictableSecureRandom.string_from(HEX_ALPHABET, (length || 16) * 2)[0, length || 16]
        end
      end
    end
  end

  SecureRandom.singleton_class.prepend(Spree::OpenAPIDeterminism::PredictableSecureRandom)

  RSpec.configure do |config|
    config.before(:suite) do
      Timecop.freeze(Spree::OpenAPIDeterminism::FROZEN_TIME)
    end

    config.after(:suite) do
      Timecop.return
    end

    # Reset before each example rather than once for the run, so a value shown
    # in one example does not depend on how many records the examples before it
    # happened to create. Without this, adding a spec shifts every random value
    # generated after it and the diff spreads across unrelated endpoints.
    #
    # FactoryBot's own sequences are deliberately left alone: they already count
    # from one per process, so they are stable, and rewinding them mid-run would
    # hand out an SKU or email that another example already claimed.
    config.before do |example|
      example_key = example.metadata[:full_description]
      example_seed = Spree::OpenAPIDeterminism::RANDOM_SEED ^ Digest::MD5.hexdigest(example_key)[0, 15].to_i(16)

      srand(example_seed)
      FFaker::Random.seed = example_seed
      Spree::OpenAPIDeterminism::PredictableSecureRandom.scope!(example_key)

      # The examples include signed JWTs. Their payloads are already stable
      # (a frozen clock fixes `exp`, the SecureRandom override fixes `jti`),
      # but the signature also depends on the signing secret, which otherwise
      # falls through to the dummy app's `secret_key_base` — generated when
      # that app is built and so different on every machine. Without this the
      # specs reproduce for whoever generated them and for nobody else.
      #
      # Set per example, not once for the suite: the suite resets Spree's
      # preferences before every example, which would wipe a one-off value.
      Spree::Api::Config[:jwt_secret_key] = Spree::OpenAPIDeterminism::JWT_SECRET
    end
  end
end
