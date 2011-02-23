Factory.define(:tracker) do |f|
  f.environment { Rails.env }
  f.analytics_id 'A100'
  f.active true
end
