require 'test/unit'
require 'test/unit/testresult'

require 'spec/interop/test/unit/testcase'
require 'spec/interop/test/unit/testsuite_adapter'
require 'spec/interop/test/unit/autorunner'
require 'spec/interop/test/unit/testresult'
require 'spec/interop/test/unit/ui/console/testrunner'

Spec::Example::ExampleGroupFactory.default(Test::Unit::TestCase)

Test::Unit.run = true
