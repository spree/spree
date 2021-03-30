Rabl.configure do |config|
  config.include_json_root = false
  config.include_child_root = false

  # Motivation here it make it call as_json when rendering timestamps
  # and therefore display miliseconds. Otherwise it would fall to
  # JSON.dump which doesn't display the miliseconds
  config.json_engine = ActiveSupport::JSON
end
