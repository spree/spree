# frozen_string_literal: true

require 'json'

module CodeSamplesHelper
  SDK_CLIENT_INIT = <<~JS.strip
    import { createClient } from '@spree/sdk'

    const client = createClient({
      baseUrl: 'https://your-store.com',
      publishableKey: '<api-key>',
    })
  JS

  ADMIN_SDK_CLIENT_INIT = <<~JS.strip
    import { createAdminClient } from '@spree/admin-sdk'

    const client = createAdminClient({
      baseUrl: 'https://your-store.com',
      secretKey: 'sk_xxx',
    })
  JS

  SDK_EXAMPLES_ROOT = File.expand_path('../../../../packages/sdk/examples', __dir__)
  ADMIN_SDK_EXAMPLES_ROOT = File.expand_path('../../../../packages/admin-sdk/examples', __dir__)

  # Match `// region:example` / `// endregion:example` markers and extract
  # the body between them. The markers can have arbitrary indentation.
  SDK_EXAMPLE_REGION = /^[ \t]*\/\/\s*region:example\s*\n(.*?)^[ \t]*\/\/\s*endregion:example/m

  EXAMPLE_CACHE = {}

  # Appends code samples to the operation's `x-codeSamples`, so several
  # example helpers (Admin SDK, CLI, …) can contribute to the same endpoint
  # without clobbering each other. Order of calls is the order shown in docs.
  def code_samples(*samples)
    existing = metadata[:operation][:'x-codeSamples'] || []
    metadata[:operation][:'x-codeSamples'] = existing + samples.map do |sample|
      { lang: sample[:lang], label: sample[:label], source: sample[:source].strip }
    end
  end

  # Renders a Store SDK code sample from a typechecked example file under
  # `packages/sdk/examples/`. The file must be a complete `.ts` module
  # (imports + `createClient` initializer) so `tsc` can verify it against
  # the live SDK types; the helper extracts only the body between
  # `// region:example` / `// endregion:example` markers and re-prepends
  # the canonical client init block so rendered docs stay consistent
  # across endpoints.
  #
  #   sdk_example 'products/list'
  #     → packages/sdk/examples/products/list.ts
  def sdk_example(name)
    source = EXAMPLE_CACHE[[:store, name]] ||= load_example_body(SDK_EXAMPLES_ROOT, name, 'Store SDK')
    code_samples(
      {
        lang: 'javascript',
        label: 'Spree SDK',
        source: "#{SDK_CLIENT_INIT}\n\n#{source}\n"
      }
    )
  end

  # Mirrors `sdk_example` for the admin SDK — examples live under
  # `packages/admin-sdk/examples/` and the canonical init block uses
  # `createAdminClient`. Also emits a matching `spree api` CLI sample, derived
  # from the operation's verb + path, so every documented Admin endpoint shows
  # SDK *and* CLI usage side by side (à la Stripe's per-endpoint CLI tab).
  def admin_sdk_example(name)
    source = EXAMPLE_CACHE[[:admin, name]] ||= load_example_body(ADMIN_SDK_EXAMPLES_ROOT, name, 'Admin SDK')
    code_samples(
      {
        lang: 'javascript',
        label: 'Spree Admin SDK',
        source: "#{ADMIN_SDK_CLIENT_INIT}\n\n#{source}\n"
      }
    )
    admin_cli_example(sdk_body_json(source), sdk_call_has_args(source))
  end

  # Emits a `spree api` CLI code sample for the current operation, derived from
  # its HTTP verb + path template (no per-endpoint authoring — the CLI is a
  # generic verb client, so the shape is mechanical). With the SDK example,
  # each endpoint shows two tabs: SDK and CLI.
  #
  # `{id}` placeholders are kept verbatim — an obvious template the reader
  # fills in, not a fake prefixed ID that looks copy-pasteable but isn't
  # (prefixes vary per resource: ord_/prod_/…).
  #
  # NOTE: Mintlify dedupes code samples by `lang` and renders one tab per
  # language, labeling the dropdown chip with the lang (not `label`). So we
  # can't show CLI + cURL as separate tabs (both want a shell-family lang) —
  # we use `bash` for the CLI (real shell highlighting, chip reads "Bash") and
  # drop the redundant cURL, which the HTTP request panel already covers.
  #
  # `sdk_body_json` is the request body as compact JSON, extracted from the SDK
  # example so the two samples stay in sync by construction. `has_args` is true
  # when the SDK call passed any arguments at all. The `-d` flag is rendered as:
  #   - the real JSON body when one was extracted;
  #   - a `{ ... }` placeholder when the call takes args but no object body
  #     (ID-only state-transition actions that *could* accept a body);
  #   - omitted entirely when the SDK call takes no args (e.g. auth.logout(),
  #     auth.refresh()) — those endpoints genuinely have no request body.
  def admin_cli_example(sdk_body_json = nil, has_args = true)
    verb = metadata.dig(:operation, :verb).to_s
    template = metadata.dig(:path_item, :template).to_s
    return if verb.empty? || template.empty?

    cli_path = template.sub(%r{\A/api/v3/admin}, '')
    source = "spree api #{verb} #{cli_path}"
    if %w[post put patch].include?(verb)
      if sdk_body_json && !sdk_body_json.empty?
        source += " -d '#{sdk_body_json}'"
      elsif has_args
        source += " -d '{ ... }'"
      end
    end

    code_samples(
      lang: 'bash',
      label: 'Spree CLI',
      source: source
    )
  end

  # True when the first `await client.<...>(...)` call passes any argument (vs
  # a no-arg call like `auth.logout()`). Used to decide whether a bodyless
  # write verb should still show a `-d '{ ... }'` placeholder.
  def sdk_call_has_args(source)
    call_index = source.index('await client.')
    return false if call_index.nil?

    paren_open = source.index('(', call_index)
    return false if paren_open.nil?

    args = balanced_slice(source, paren_open, '(', ')')
    return false if args.nil?

    !args[1...-1].strip.empty?
  end

  # Extracts the request-body object literal from an SDK example region and
  # converts it to compact JSON. The body is the last top-level `{...}`
  # argument of the first `await client.<...>(...)` call — covering single-arg
  # (`create({...})`), two-arg (`create('parentId', {...})`), and deeply
  # nested shapes. Returns nil when no body literal can be extracted.
  def sdk_body_json(source)
    literal = extract_sdk_body_literal(source)
    return nil if literal.nil?

    ts_object_literal_to_json(literal)
  rescue StandardError
    nil
  end

  # Returns the body object-literal text (`{ ... }`) of the first
  # `await client.<...>(...)` call in the SDK example, or nil if absent.
  def extract_sdk_body_literal(source)
    call_index = source.index('await client.')
    return nil if call_index.nil?

    paren_open = source.index('(', call_index)
    return nil if paren_open.nil?

    args = balanced_slice(source, paren_open, '(', ')')
    return nil if args.nil?

    # `args` includes the surrounding parens — strip them, then find the last
    # top-level `{...}` argument (the request body; a leading `'parentId',` or
    # a variable like `promotionId` is ignored). The brace must be at argument
    # depth 0 so nested object literals (e.g. items within `variants`) aren't
    # mistaken for the body.
    inner = args[1...-1]
    last_brace = last_top_level_brace_index(inner)
    return nil if last_brace.nil?

    balanced_slice(inner, last_brace, '{', '}')
  end

  # Returns the index of the last top-level (argument-depth-0) `{` in the call's
  # argument string, skipping over string literals and nested delimiters.
  def last_top_level_brace_index(inner)
    depth = 0
    quote = nil
    result = nil
    i = 0
    while i < inner.length
      ch = inner[i]
      if quote
        quote = nil if ch == quote && inner[i - 1] != '\\'
      elsif ch == "'" || ch == '"' || ch == '`'
        quote = ch
      elsif '{['.include?(ch)
        result = i if ch == '{' && depth.zero?
        depth += 1
      elsif '}]'.include?(ch)
        depth -= 1
      end
      i += 1
    end
    result
  end

  # Returns the substring of `str` starting at `open_index` (which must hold
  # `open_char`) through its matching `close_char`, respecting nested
  # delimiters and skipping over string literals. Returns nil if unbalanced.
  def balanced_slice(str, open_index, open_char, close_char)
    depth = 0
    quote = nil
    i = open_index
    while i < str.length
      ch = str[i]
      if quote
        quote = nil if ch == quote && str[i - 1] != '\\'
      elsif ch == "'" || ch == '"' || ch == '`'
        quote = ch
      elsif ch == open_char
        depth += 1
      elsif ch == close_char
        depth -= 1
        return str[open_index..i] if depth.zero?
      end
      i += 1
    end
    nil
  end

  # Converts a TypeScript object-literal string into compact (minified) JSON.
  # Handles single-quoted strings, unquoted keys, trailing commas, and `//`
  # line comments — without mangling characters inside string values.
  def ts_object_literal_to_json(literal)
    tokens = tokenize_ts_literal(literal)
    json = tokens.join
    JSON.parse(json) # validate; raises on malformed input
    json
  end

  # Tokenizes a TS object literal into JSON-equivalent pieces: string literals
  # are normalized to double-quoted JSON strings; `//` comments are dropped;
  # identifiers used as object keys are quoted; everything else (numbers,
  # booleans, braces, brackets, colons) passes through, with whitespace and
  # trailing commas collapsed.
  def tokenize_ts_literal(src)
    out = []
    i = 0
    len = src.length
    while i < len
      ch = src[i]
      if ch == "'" || ch == '"' || ch == '`'
        str, i = read_string(src, i)
        out << str
      elsif ch == '/' && src[i + 1] == '/'
        i += 1 while i < len && src[i] != "\n" # skip line comment
      elsif ch =~ /\s/
        i += 1 # drop insignificant whitespace
      elsif ch == ','
        out << ',' unless trailing_comma?(src, i)
        i += 1
      elsif ch =~ /[A-Za-z_$]/
        word, i = read_identifier(src, i)
        out << quote_key_or_keyword(word, src, i)
      else
        out << ch # braces, brackets, colon, digits, sign, dot, etc.
        i += 1
      end
    end
    out
  end

  # Reads a quoted string starting at `i` and returns it as a JSON double-quoted
  # string plus the index just past the closing quote. Inner double quotes are
  # escaped; existing escapes are preserved.
  def read_string(src, i)
    quote = src[i]
    i += 1
    buffer = +''
    while i < src.length
      ch = src[i]
      if ch == '\\'
        buffer << ch << src[i + 1].to_s
        i += 2
        next
      end
      break if ch == quote

      buffer << ch
      i += 1
    end
    i += 1 # consume closing quote
    [%("#{buffer.gsub('"', '\\"')}"), i]
  end

  def read_identifier(src, i)
    start = i
    i += 1 while i < src.length && src[i] =~ /[A-Za-z0-9_$]/
    [src[start...i], i]
  end

  # Quotes an identifier when it's used as an object key (next non-space char
  # is `:`); leaves literal keywords (`true`/`false`/`null`) bare so they emit
  # as JSON literals.
  def quote_key_or_keyword(word, src, next_index)
    return word if %w[true false null].include?(word)

    j = next_index
    j += 1 while j < src.length && src[j] =~ /\s/
    src[j] == ':' ? %("#{word}") : word
  end

  # True when the comma at `i` is a trailing comma (next significant char is a
  # closing `}`/`]`), which JSON forbids.
  def trailing_comma?(src, i)
    j = i + 1
    while j < src.length
      ch = src[j]
      if ch =~ /\s/
        j += 1
      elsif ch == '/' && src[j + 1] == '/'
        j += 1 while j < src.length && src[j] != "\n"
      else
        return ch == '}' || ch == ']'
      end
    end
    true
  end

  def load_example_body(root, name, label)
    path = File.join(root, "#{name}.ts")
    raise "#{label} example not found: #{path}" unless File.exist?(path)

    body = File.read(path).match(SDK_EXAMPLE_REGION)&.captures&.first
    raise "#{label} example #{name.inspect} has no `// region:example` marker" if body.nil?

    body.rstrip.strip_heredoc.strip
  end

  # Appends a `**Required scope:**` line to the operation description.
  # Use in admin integration specs to surface scope requirements in the
  # rendered Mintlify docs without inventing a custom OpenAPI extension.
  #
  #   admin_scope :read, :orders
  #   admin_scope :write, :customers
  def admin_scope(action, resource)
    admin_scope_note("`#{action}_#{resource}`")
  end

  # Free-form variant for endpoints whose required scope is resolved at
  # request time (e.g. exports — gated by the exported resource's scope).
  def admin_scope_note(text)
    line = "**Required scope:** #{text} (for API-key authentication)."
    existing = metadata[:operation][:description].to_s
    metadata[:operation][:description] = existing.empty? ? line : "#{existing}\n\n#{line}"
  end
end

RSpec.configure do |config|
  config.extend CodeSamplesHelper, type: :request
end
