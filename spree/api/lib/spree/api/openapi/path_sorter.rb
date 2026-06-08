# frozen_string_literal: true

module Spree
  module Api
    module OpenAPI
      # Reorders the `paths:` block of a generated OpenAPI YAML so paths are grouped
      # by tag, in the same order as the top-level `tags:` array.
      #
      # rswag emits paths in the order specs are loaded (alphabetical by filename),
      # which doesn't match the curated `tags:` array order in swagger_helper.rb.
      # Mintlify groups sidebar sections by the *first appearance* of each tag in
      # `paths:` — so after this sort runs, the sidebar matches the `tags:` array.
      #
      # The reorder is line-based to preserve the exact text formatting that
      # rswag/Psych produced (indentation, multi-line string wrapping, etc.).
      module PathSorter
        module_function

        # Sort the `paths:` block in `path` so each path's first-operation primary
        # tag follows the order defined in the document's top-level `tags:` array.
        # Returns true if the file was rewritten, false if already sorted.
        def sort_file!(path)
          original = File.read(path)
          sorted = sort_text(original)
          return false if sorted == original

          File.write(path, sorted)
          true
        end

        # Pure-string variant: sort a YAML document's `paths:` block by tag order.
        def sort_text(yaml)
          lines = yaml.lines
          tag_rank = extract_tag_rank(lines)
          return yaml if tag_rank.empty?

          paths_start = lines.index { |l| l.start_with?('paths:') }
          return yaml unless paths_start

          paths_end_exclusive = (paths_start + 1...lines.size).find do |i|
            line = lines[i]
            line.match?(/\A[A-Za-z]/) || line.start_with?('x-')
          end || lines.size

          blocks = collect_path_blocks(lines, paths_start + 1, paths_end_exclusive)
          return yaml if blocks.empty?

          unknown_rank = tag_rank.size
          sorted_blocks = blocks.each_with_index.sort_by do |block, original_index|
            [tag_rank.fetch(block[:tag], unknown_rank), original_index]
          end.map(&:first)

          prefix = lines[0..paths_start].join
          suffix = lines[paths_end_exclusive..].to_a.join
          prefix + sorted_blocks.map { |b| b[:text] }.join + suffix
        end

        # Parse the top-level `tags:` block and return { tag_name => index } in
        # declared order. Returns {} if not found.
        def extract_tag_rank(lines)
          start = lines.index { |l| l.start_with?('tags:') }
          return {} unless start

          rank = {}
          i = start + 1
          while i < lines.size
            line = lines[i]
            if line.start_with?('- name: ')
              rank[line.sub('- name: ', '').strip] = rank.size
            elsif line.match?(/\A[A-Za-z]/) || line.start_with?('x-')
              break
            end
            i += 1
          end
          rank
        end

        # Collect each path block as { tag:, text: } from lines[range].
        # A path block starts on a line beginning with two spaces + a quote.
        def collect_path_blocks(lines, start_idx, end_idx_exclusive)
          blocks = []
          current_start = nil

          (start_idx...end_idx_exclusive).each do |i|
            if path_header?(lines[i])
              blocks << build_block(lines, current_start, i) if current_start
              current_start = i
            end
          end
          blocks << build_block(lines, current_start, end_idx_exclusive) if current_start

          blocks
        end

        def path_header?(line)
          line.start_with?('  "/') || line.start_with?('  /')
        end

        def build_block(lines, from, to_exclusive)
          slice = lines[from...to_exclusive]
          {
            tag: extract_primary_tag(slice),
            text: slice.join
          }
        end

        # Within a path block, find the first `tags:` line and return the first
        # tag value following it (the path block's "primary" tag).
        def extract_primary_tag(slice)
          slice.each_with_index do |line, idx|
            next unless line.match?(/\A {6}tags:\s*$/)

            slice[(idx + 1)..].each do |next_line|
              if next_line.start_with?('      - ')
                value = next_line[8..].strip
                return value unless value.empty?
              end
              break if next_line.match?(/\A {0,4}\S/)
            end
          end
          nil
        end
      end
    end
  end
end
