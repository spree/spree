require File.dirname(__FILE__) + '/../../../spec_helper'
begin
  require 'nokogiri' # Needed to compare generated with wanted HTML
rescue LoadError
  warn "nokogiri not loaded -- skipping TextMateFormatter specs"
  return
end
require 'spec/runner/formatter/text_mate_formatter'

module Spec
  module Runner
    module Formatter
      describe TextMateFormatter do
        attr_reader :root, :suffix, :expected_file
        before do
          @root = File.expand_path(File.dirname(__FILE__) + '/../../../..')
          @suffix = jruby? ? '-jruby' : ''
          @expected_file = File.dirname(__FILE__) + "/text_mate_formatted-#{::RUBY_VERSION}#{suffix}.html"
        end

        def produces_html_identical_to_manually_designed_document(opt)
          root = File.expand_path(File.dirname(__FILE__) + '/../../../..')

          Dir.chdir(root) do
            args = [
              'examples/failing/mocking_example.rb',
                'examples/failing/diffing_spec.rb',
                'examples/passing/stubbing_example.rb',
                'examples/passing/pending_example.rb',
                '--format',
                'textmate',
                opt
            ]
            err = StringIO.new
            out = StringIO.new

            run_with ::Spec::Runner::OptionParser.parse(args, err, out)
              
            yield(out.string)
          end          
        end

        # # Uncomment this spec temporarily in order to overwrite the expected with actual.
        # # Use with care!!!
        # describe "functional spec file generator" do
        #   it "generates a new comparison file" do
        #     Dir.chdir(root) do
        #       args = ['examples/failing/mocking_example.rb', 'examples/failing/diffing_spec.rb', 'examples/passing/stubbing_example.rb',  'examples/passing/pending_example.rb', '--format', 'textmate', '--diff']
        #       err = StringIO.new
        #       out = StringIO.new
        #       Spec::Runner::CommandLine.run(
        #         ::Spec::Runner::OptionParser.parse(args, err, out)
        #       )
        # 
        #       seconds = /\d+\.\d+ seconds/
        #       html = out.string.gsub seconds, 'x seconds'
        # 
        #       File.open(expected_file, 'w') {|io| io.write(html)}
        #     end
        #   end
        # end

         describe "functional spec using --diff" do
           it "should produce HTML identical to the one we designed manually with --diff" do
             produces_html_identical_to_manually_designed_document("--diff") do |html|
               suffix = jruby? ? '-jruby' : ''
               expected_file = File.dirname(__FILE__) + "/text_mate_formatted-#{::VERSION}#{suffix}.html"
               unless File.file?(expected_file)
                 raise "There is no HTML file with expected content for this platform: #{expected_file}"
               end
               expected_html = File.read(expected_file)

               seconds = /\d+\.\d+ seconds/
               html.gsub! seconds, 'x seconds'
               expected_html.gsub! seconds, 'x seconds'

               doc = Nokogiri::HTML(html)
               backtraces = doc.search("div.backtrace a")
               doc.search("div.backtrace").remove

               expected_doc = Nokogiri::HTML(expected_html)
               expected_doc.search("div.backtrace").remove

               doc.inner_html.should == expected_doc.inner_html

               backtraces.each do |backtrace_link|
                 backtrace_link['href'].should include("txmt://open?url=")
               end
             end
           end

         end

         describe "functional spec using --dry-run" do
           it "should produce HTML identical to the one we designed manually with --dry-run" do
             produces_html_identical_to_manually_designed_document("--dry-run") do |html, expected_html|
               html.should =~ /This was a dry-run/m
             end
           end
         end
      end
    end
  end
end
