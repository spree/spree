require 'rake'
require 'spec/rake/verify_rcov'

RCov::VerifyTask.new(:verify_rcov => :spec) do |t|
  t.threshold = 100.0
  t.index_html = 'coverage/index.html'
end
