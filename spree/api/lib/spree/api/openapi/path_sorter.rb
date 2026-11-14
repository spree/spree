# frozen_string_literal: true

module Spree
  module Api
    module OpenAPI
      # Orders a generated OpenAPI YAML for the Mintlify sidebar: Authentication
      # first, every other tag alphabetical.
      #
      # rswag emits paths in the order specs are loaded, and Mintlify renders one
      # sidebar group per tag in the order tags first appear in `paths:`. So this
      # reorders the `paths:` block by each path's primary tag, and rewrites the
      # top-level `tags:` block in the same order, adding any tag an operation
      # uses but swagger_helper.rb doesn't declare.
      #
      # The reorder is line-based to preserve the exact text formatting that
      # rswag/Psych produced (indentation, multi-line string wrapping, etc.).
      module PathSorter
        FIRST_TAG = 'Authentication'

        module_function

        # Returns true if the file was rewritten, false if already sorted.
        def sort_file!(path)
          original = File.read(path, encoding: Encoding::UTF_8)
          sorted = sort_text(original)
          return false if sorted == original

          File.write(path, sorted)
          true
        end

        def sort_text(yaml)
          lines = yaml.lines

          paths_range = block_range(lines, 'paths:')
          return yaml unless paths_range

          blocks = collect_path_blocks(lines, paths_range)
          return yaml if blocks.empty?

          tags_range = block_range(lines, 'tags:')
          tag_entries = tags_range ? collect_tag_entries(lines, tags_range) : {}
          blocks.each { |b| tag_entries[b[:tag]] ||= "- name: #{b[:tag]}\n" if b[:tag] }

          order = tag_entries.keys.sort_by { |name| tag_sort_key(name) }
          rank = order.each_with_index.to_h

          sorted_blocks = blocks.each_with_index.sort_by do |block, index|
            [rank.fetch(block[:tag], rank.size), index]
          end.map(&:first)

          replacements = { paths_range => sorted_blocks.sum('') { |block| block[:text] } }
          replacements[tags_range] = order.map { |name| tag_entries[name] }.join if tags_range

          replace_ranges(lines, replacements)
        end

        def tag_sort_key(name)
          [name == FIRST_TAG ? 0 : 1, name.downcase]
        end

        # The body lines of a top-level key, as a range excluding the key itself.
        def block_range(lines, key)
          start = lines.index { |l| l.start_with?(key) }
          return unless start

          finish = ((start + 1)...lines.size).find { |i| top_level?(lines[i]) } || lines.size
          (start + 1)...finish
        end

        def top_level?(line)
          line.match?(/\A[A-Za-z]/) || line.start_with?('x-')
        end

        def replace_ranges(lines, replacements)
          out = +''
          cursor = 0
          replacements.sort_by { |range, _| range.begin }.each do |range, text|
            out << lines[cursor...range.begin].join << text
            cursor = range.end
          end
          out << lines[cursor..].to_a.join
        end

        # { tag_name => entry_text } in declared order.
        def collect_tag_entries(lines, range)
          entries = {}
          current = nil
          range.each do |i|
            line = lines[i]
            if line.start_with?('- name: ')
              current = unquote(line.sub('- name: ', '').strip)
              entries[current] = +''
            end
            entries[current] << line if current
          end
          entries
        end

        # Each path block as { tag:, text: }. A block starts on a line beginning
        # with two spaces and a slash, optionally quoted.
        def collect_path_blocks(lines, range)
          starts = range.select { |i| path_header?(lines[i]) }
          starts.each_with_index.map do |from, idx|
            to = starts[idx + 1] || range.end
            slice = lines[from...to]
            { tag: extract_primary_tag(slice), text: slice.join }
          end
        end

        def path_header?(line)
          line.start_with?('  "/') || line.start_with?('  /')
        end

        # The first tag of the first operation in a path block.
        def extract_primary_tag(slice)
          slice.each_with_index do |line, idx|
            next unless line.match?(/\A {6}tags:\s*$/)

            slice[(idx + 1)..].each do |next_line|
              if next_line.start_with?('      - ')
                value = next_line[8..].strip
                return unquote(value) unless value.empty?
              end
              break if next_line.match?(/\A {0,4}\S/)
            end
          end
          nil
        end

        def unquote(value)
          value.match?(/\A(["']).*\1\z/) ? value[1..-2] : value
        end
      end
    end
  end
end
