# Settings for the examples that call Klaviyo, recorded with RECORD_VCR=1:
#
#   KLAVIYO_PRIVATE_API_KEY  a key with Events, Lists, Profiles, Subscriptions
#                            (read and write) and Data Privacy (write)
#   KLAVIYO_LIMITED_API_KEY  a key without lists:read and data-privacy:write
#   KLAVIYO_LIST_ID          a double opt-in list
#   KLAVIYO_TEST_INBOX       a mailbox that accepts plus-addressing, so
#                            Klaviyo's confirmation emails reach a real inbox
#
# On replay none is needed: requests match on method and path, and the
# placeholders below stand in.
module KlaviyoHelpers
  def klaviyo_private_api_key
    ENV.fetch('KLAVIYO_PRIVATE_API_KEY', 'pk_replay_key')
  end

  def klaviyo_limited_api_key
    ENV.fetch('KLAVIYO_LIMITED_API_KEY', 'pk_replay_limited_key')
  end

  def klaviyo_list_id
    ENV.fetch('KLAVIYO_LIST_ID', 'LIST01')
  end

  # @param tag [String] names what the address is for, so a recording's
  #   addresses never collide with an earlier recording's
  def klaviyo_test_address(tag)
    local, domain = ENV.fetch('KLAVIYO_TEST_INBOX', 'klaviyo-test@example.com').split('@', 2)
    "#{local}+#{tag}-#{SecureRandom.hex(4)}@#{domain}"
  end

  def recording_integration(key: klaviyo_private_api_key, list_id: klaviyo_list_id)
    build(:klaviyo_integration, store: @default_store, preferred_klaviyo_private_api_key: key,
                                preferred_default_newsletter_list_id: list_id)
  end
end

RSpec.configure do |config|
  config.include KlaviyoHelpers
end
