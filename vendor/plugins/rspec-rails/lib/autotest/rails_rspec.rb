# (c) Copyright 2006 Nick Sieger <nicksieger@gmail.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

$:.push(*Dir["vendor/rails/*/lib"])

require 'active_support'
require 'autotest/rspec'

Autotest.add_hook :initialize do |at|
  %w{^config/ ^coverage/ ^db/ ^doc/ ^log/ ^public/ ^script ^vendor/rails ^vendor/plugins previous_failures.txt}.each do |exception|
    at.add_exception(exception)
  end
  
  at.clear_mappings
  
  at.add_mapping(%r%^(test|spec)/fixtures/(.*).yml$%) { |_, m|
    ["spec/models/#{m[2].singularize}_spec.rb"] + at.files_matching(%r%^spec\/views\/#{m[2]}/.*_spec\.rb$%)
  }
  at.add_mapping(%r%^spec/(models|controllers|views|helpers|lib)/.*rb$%) { |filename, _|
    filename
  }
  at.add_mapping(%r%^app/models/(.*)\.rb$%) { |_, m|
    ["spec/models/#{m[1]}_spec.rb"]
  }
  at.add_mapping(%r%^app/views/(.*)$%) { |_, m|
    at.files_matching %r%^spec/views/#{m[1]}_spec.rb$%
  }
  at.add_mapping(%r%^app/controllers/(.*)\.rb$%) { |_, m|
    if m[1] == "application"
      at.files_matching %r%^spec/controllers/.*_spec\.rb$%
    else
      ["spec/controllers/#{m[1]}_spec.rb"]
    end
  }
  at.add_mapping(%r%^app/helpers/(.*)_helper\.rb$%) { |_, m|
    if m[1] == "application" then
      at.files_matching(%r%^spec/(views|helpers)/.*_spec\.rb$%)
    else
      ["spec/helpers/#{m[1]}_helper_spec.rb"] + at.files_matching(%r%^spec\/views\/#{m[1]}/.*_spec\.rb$%)
    end
  }
  at.add_mapping(%r%^config/routes\.rb$%) {
    at.files_matching %r%^spec/(controllers|views|helpers)/.*_spec\.rb$%
  }
  at.add_mapping(%r%^config/database\.yml$%) { |_, m|
    at.files_matching %r%^spec/models/.*_spec\.rb$%
  }
  at.add_mapping(%r%^(spec/(spec_helper|shared/.*)|config/(boot|environment(s/test)?))\.rb$%) {
    at.files_matching %r%^spec/(models|controllers|views|helpers)/.*_spec\.rb$%
  }
  at.add_mapping(%r%^lib/(.*)\.rb$%) { |_, m|
    ["spec/lib/#{m[1]}_spec.rb"]
  }
end

class Autotest::RailsRspec < Autotest::Rspec

  def spec_command
    "script/spec"
  end
    
end
