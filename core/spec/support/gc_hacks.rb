# From: http://www.rubyinside.com/careful-cutting-to-get-faster-rspec-runs-with-rails-5207.html
counter = -1
RSpec.configure do |config|
  config.after(:each) do
    unless RUBY_VERSION =~ /1\.9\.2/
      counter += 1
      if counter > 9
        GC.enable
        GC.start
        GC.disable
        counter = 0
      end
    end
  end

  config.after(:suite) do
    counter = 0
  end
end
