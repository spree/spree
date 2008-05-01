require 'rake'
require 'spec/rake/verify_rcov'

RCov::VerifyTask.new(:verify_rcov => :spec) do |t|
  t.threshold = 100.0 # Make sure you have rcov 0.7 or higher!
  t.index_html = '../doc/output/coverage/index.html'
end
