# Loads fixtures into the database when running the test app via the console
(ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir.glob(Rails.root.join(, '../fixtures/*.{yml,csv}'))).each do |fixture_file|
  Fixtures.create_fixtures(Rails.root.join(, '../fixtures'), File.basename(fixture_file, '.*'))
end
