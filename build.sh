 alias set_gemfile='export BUNDLE_GEMFILE="`pwd`/Gemfile"'
 rm Gemfile.lock
 bundle check || bundle install
 bundle exec rake test_app
 cd api; set_gemfile; rm Gemfile.lock; bundle install; bundle exec rspec spec
 cd ../backend; set_gemfile; rm Gemfile.lock; bundle install; bundle exec rspec spec
 cd ../core; set_gemfile; rm Gemfile.lock; bundle install; bundle exec rspec spec
 cd ../dash; set_gemfile; rm Gemfile.lock; bundle install; bundle exec rspec spec
 cd ../frontend; set_gemfile; rm Gemfile.lock; bundle install; bundle exec rspec spec
