task :ruby_env do
  RUBY_APP = if RUBY_PLATFORM =~ /java/
    "jruby"
  else
    "ruby"
  end unless defined? RUBY_APP
end
