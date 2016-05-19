class FencedCodeBlocks < Nanoc::Filter
  identifier :fenced_code_blocks

  def run(content, _params = {})
    content = content.gsub(/^```\s?(.*?)\n(.*?)```/m) do
      "~~~ #{$1}\n" +
        "#{$2}\n" +
        "~~~"
    end
    content
  end
end
