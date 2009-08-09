# Loads fixtures into the database when running the test app via the console
(ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : Dir.glob(File.join(Rails.root, '../fixtures/*.{yml,csv}'))).each do |fixture_file|
  Fixtures.create_fixtures(File.join(Rails.root, '../fixtures'), File.basename(fixture_file, '.*'))
end
