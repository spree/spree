desc "Set the environment variable RAILS_ENV='development'."
task :development do
  ENV['RAILS_ENV'] = Rails.env = 'development'
  Rake::Task[:environment].invoke
end

desc "Set the environment variable RAILS_ENV='production'."
task :production do
  ENV['RAILS_ENV'] = Rails.env = 'production'
  Rake::Task[:environment].invoke
end
