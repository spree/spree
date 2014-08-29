class AddTOCFilter < Nanoc::Filter

  identifier :add_toc

  def run(content, params={})
    content.gsub('{{TOC}}') do
      # Find all top-level sections
      doc = Nokogiri::HTML(content)
      headers = []
      doc.css("#main-content").css("h2, h3").each do |header_tag|
        header = { :title => header_tag.inner_html, :id => header_tag['id'] }
        if header_tag.name == 'h2'
          headers << header
          @current_header = header
        else
          @current_header[:subs] ||= []
          @current_header[:subs] << { :title => header_tag.inner_html, :id => header_tag['id'] }
        end
      end

      # Build table of contents
      res = '<ol class="toc">'
      headers.each do |header|
        res << %[<li><a href="##{header[:id]}">#{header[:title]}</a>]
        if header[:subs]
          res << "<ol>"
          header[:subs].each do |header|
            res << %[<li><a href="#{header[:id]}">#{header[:title]}</a>]
          end
          res << "</ol>"
        end
        res << "</li>"
      end
      res << '</ol>'

      res
    end
  end

end

