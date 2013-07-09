class ParseInfoBoxes < Nanoc::Filter

  identifier :parse_info_boxes

  def run(content, params={})
    content = content.gsub(/^!!!\n(.*?)!!!/m) do
      generate_div("warning", $1)
    end

    content = content.gsub(/^\*\*\*\n(.*?)\*\*\*/m) do
      generate_div("note", $1)
    end

    content = content.gsub(/^\$\$\$\n(.*?)\$\$\$/m) do
      "<p>**************** TODO ****************</p>" + $1 + "<p>**************************************</p>"
      #generate_div("todo", $1)
    end

    content
  end

  private

    def generate_div(klass, content)
      %{<div class="#{klass}">#{parse_inner_content(content)}</div>}
    end

    def parse_inner_content(content)
      Kramdown::Document.new(content).to_html
    end
end

