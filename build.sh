 alias set_gemfile='export BUNDLE_GEMFILE="`pwd`/Gemfile"'
 bundle exec rake test_app
 cd api; set_gemfile; bundle install; bundle exec rspec spec
 cd ../core; set_gemfile; bundle install; bundle exec rspec spec
 cd ../dash; set_gemfile; bundle install; bundle exec rspec spec
 cd ../promo; set_gemfile; bundle install; bundle exec rspec spec
