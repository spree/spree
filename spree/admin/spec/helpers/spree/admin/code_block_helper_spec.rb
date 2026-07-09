require 'spec_helper'

describe Spree::Admin::CodeBlockHelper do
  describe '#code_block' do
    it 'renders the code passed as an argument' do
      result = helper.code_block('{ "key": "value" }')

      expect(result).to have_css('div[data-controller="highlight"] pre code.language-json')
      expect(result).to include('{ &quot;key&quot;: &quot;value&quot; }')
    end

    it 'accepts a custom language' do
      result = helper.code_block('ls', language: 'bash')

      expect(result).to have_css('code.language-bash')
    end

    it 'renders the code passed as a block' do
      result = helper.code_block { 'bin/rails server' }

      expect(result).to have_css('pre code')
      expect(result).to include('bin/rails server')
    end

    it 'accepts options as the first argument with a block' do
      result = helper.code_block(language: 'bash') { 'bin/rails server' }

      expect(result).to have_css('code.language-bash')
      expect(result).to include('bin/rails server')
    end

    it 'strips common indentation from block content' do
      result = helper.code_block { "\n    FOO=bar\n    BAZ=qux\n" }

      expect(result).to include(">FOO=bar\nBAZ=qux<")
    end
  end
end
