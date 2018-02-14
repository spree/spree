require 'database_cleaner'

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with :truncation
  end

  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  # Before each spec check if it is a Javascript test and switch between using database transactions or not where necessary.
  config.before(:each, :js) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before do
    DatabaseCleaner.start
  end

  # After each spec clean the database.
  config.after do
    DatabaseCleaner.clean
  end
end
