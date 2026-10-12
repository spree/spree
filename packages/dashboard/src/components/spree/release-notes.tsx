import ReactMarkdown, { type Components } from 'react-markdown'
import rehypeRaw from 'rehype-raw'
import rehypeSanitize from 'rehype-sanitize'
import remarkGfm from 'remark-gfm'

// Release notes mix markdown with raw HTML (screenshots are `<img>` tags), so
// HTML is parsed and then sanitized with GitHub's own allowlist: nothing a
// release author writes can run script in the dashboard.
const REMARK_PLUGINS = [remarkGfm]
const REHYPE_PLUGINS = [rehypeRaw, rehypeSanitize]

const COMPONENTS: Components = {
  h1: ({ node: _node, ...props }) => (
    <h3 className="mt-6 mb-2 font-semibold text-base first:mt-0" {...props} />
  ),
  h2: ({ node: _node, ...props }) => (
    <h3 className="mt-6 mb-2 font-semibold text-base first:mt-0" {...props} />
  ),
  h3: ({ node: _node, ...props }) => <h4 className="mt-4 mb-1 font-semibold text-sm" {...props} />,
  p: ({ node: _node, ...props }) => <p className="my-2 leading-relaxed" {...props} />,
  ul: ({ node: _node, ...props }) => <ul className="my-2 list-disc space-y-1 ps-5" {...props} />,
  ol: ({ node: _node, ...props }) => <ol className="my-2 list-decimal space-y-1 ps-5" {...props} />,
  a: ({ node: _node, ...props }) => (
    <a
      {...props}
      target="_blank"
      rel="noopener noreferrer"
      className="font-medium underline underline-offset-3 hover:text-foreground"
    />
  ),
  img: ({ node: _node, alt, ...props }) => (
    <img
      {...props}
      alt={alt ?? ''}
      loading="lazy"
      className="my-3 h-auto max-w-full rounded-md border"
    />
  ),
  pre: ({ node: _node, ...props }) => (
    <pre
      className="my-3 overflow-x-auto rounded-md bg-muted p-3 text-xs [&_code]:bg-transparent [&_code]:p-0"
      {...props}
    />
  ),
  code: ({ node: _node, ...props }) => (
    <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs" {...props} />
  ),
}

/** Release notes from GitHub, rendered as the dashboard's own text. */
export function ReleaseNotes({ markdown }: { markdown: string }) {
  return (
    <div className="min-w-0 break-words text-sm">
      <ReactMarkdown
        remarkPlugins={REMARK_PLUGINS}
        rehypePlugins={REHYPE_PLUGINS}
        components={COMPONENTS}
      >
        {markdown}
      </ReactMarkdown>
    </div>
  )
}
