Rails.application.config.after_initialize do
  require 'mobility/action_text'
end

Mobility.configure do |config|
  config.plugins do
    ransack
    backend :table
    active_record
    reader
    writer
    backend_reader
    query
    cache
    store_based_fallbacks
    locale_accessors
    presence
    dirty
    column_fallback
  end
end
