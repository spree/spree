# module Spree
#   module TestingSupport
#     module Caching
      # def cache_writes
      #   @cache_write_events
      # end

      # def assert_written_to_cache(key)
      #   unless @cache_write_events.detect { |event| event[:key].starts_with?(key) }
      #     raise %Q{Expected to find #{key} in the cache, but didn't.

  # Cache writes:
  # #{@cache_write_events.join("\n")}
      #     }
      #   end
      # end

      # def clear_cache_events
      #   @cache_read_events = []
      #   @cache_write_events = []
      # end
    # end
  # end
# end

# RSpec.configure do |config|
  # config.include Spree::TestingSupport::Caching, caching: true

  # config.before(:each, caching: true) do
    # ActionController::Base.perform_caching = true

    # ActiveSupport::Notifications.subscribe('read_fragment.action_controller') do |_event, _start_time, _finish_time, _, details|
    #   @cache_read_events ||= []
    #   @cache_read_events << details
    # end

    # ActiveSupport::Notifications.subscribe('write_fragment.action_controller') do |_event, _start_time, _finish_time, _, details|
    #   @cache_write_events ||= []
    #   @cache_write_events << details
    # end
  # end

  # config.after(:each, caching: true) do
    # ActionController::Base.perform_caching = false
    # Rails.cache.clear
  # end
# end
