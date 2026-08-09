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
