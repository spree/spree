import fs from 'node:fs'
import path from 'node:path'

/**
 * Variables exposed to template files. Keys are matched as `{{key}}` in any
 * file content and renamed inside path segments (so a directory or file named
 * `{{ruby_name}}` becomes the resolved value).
 */
export type TemplateVars = Record<string, string>

export interface RenderOptions {
  /** Source directory containing the template tree. */
  src: string
  /** Destination directory. Must not exist or be empty (unless `force` is set). */
  dst: string
  /** Variables substituted into `{{key}}` placeholders. */
  vars: TemplateVars
  /**
   * Predicate evaluated against each path *relative to `src`*. When it
   * returns `true`, the file or directory (and its children) is skipped.
   * Used to gate optional subtrees like `packages/dashboard/` behind flags.
   */
  skip?: (relPath: string) => boolean
  /**
   * Overwrite a non-empty destination. Off by default — the CLI errors
   * before calling render when the target dir has content.
   */
  force?: boolean
}

/**
 * Render a template tree from `src` into `dst`.
 *
 * Behavior:
 * - Files ending in `.tt` have their contents passed through
 *   `substitute` and are written without the `.tt` suffix.
 * - All other files are copied verbatim (no substitution — keeps binary
 *   files and code with literal `{{` tokens safe).
 * - Path segments (file and directory names) ARE substituted on both
 *   regular and `.tt` files. A directory named `lib/{{ruby_name}}`
 *   becomes `lib/spree_brands/` in the output.
 * - Subtrees skipped by the `skip` predicate are not visited; their
 *   parent directories are still created if they contain other content
 *   (e.g. `packages/` survives when `packages/engine/` is skipped).
 */
export function render(opts: RenderOptions): void {
  const { src, dst, vars, skip, force } = opts

  if (!fs.existsSync(src)) {
    throw new Error(`Template source not found: ${src}`)
  }
  if (fs.existsSync(dst)) {
    const contents = fs.readdirSync(dst)
    if (contents.length > 0 && !force) {
      throw new Error(`Destination ${dst} is not empty. Pass force=true to overwrite.`)
    }
  } else {
    fs.mkdirSync(dst, { recursive: true })
  }

  walk(src, dst, '', vars, skip)
}

function walk(
  srcRoot: string,
  dstRoot: string,
  relPath: string,
  vars: TemplateVars,
  skip?: (relPath: string) => boolean,
): void {
  const srcDir = path.join(srcRoot, relPath)
  for (const entry of fs.readdirSync(srcDir, { withFileTypes: true })) {
    const childRel = relPath ? `${relPath}/${entry.name}` : entry.name
    if (skip?.(childRel)) continue

    // Resolve any `{{var}}` tokens in the path segment itself before
    // writing to disk. Most names pass through unchanged.
    const dstName = safeSegment(substitute(entry.name, vars))
    const srcChild = path.join(srcRoot, childRel)

    if (entry.isDirectory()) {
      // Compute the destination directory path with renamed segment.
      const dstChildRel = relPath ? `${substituteSegments(relPath, vars)}/${dstName}` : dstName
      const dstChild = path.join(dstRoot, dstChildRel)
      fs.mkdirSync(dstChild, { recursive: true })
      walk(srcRoot, dstRoot, childRel, vars, skip)
      continue
    }

    // Strip the `.tt` suffix on template files so output is `package.json`
    // rather than `package.json.tt`. Non-template files keep their name.
    const isTemplate = dstName.endsWith('.tt')
    const finalName = isTemplate ? dstName.slice(0, -3) : dstName
    const dstChildRel = relPath ? `${substituteSegments(relPath, vars)}/${finalName}` : finalName
    const dstChild = path.join(dstRoot, dstChildRel)

    if (isTemplate) {
      const content = fs.readFileSync(srcChild, 'utf8')
      fs.writeFileSync(dstChild, substitute(content, vars))
    } else {
      // Use copyFile so file modes, etc. round-trip correctly. Binary
      // files (images, etc.) survive without re-encoding.
      fs.copyFileSync(srcChild, dstChild)
    }
  }
}

/**
 * Replace `{{key}}` tokens in `input` with `vars[key]`. Keys not in `vars`
 * are left untouched so users see the literal placeholder in output and
 * notice the typo, rather than getting silent empty-string substitution.
 *
 * Exported for testing; templates use it via `render()` indirectly.
 */
export function substitute(input: string, vars: TemplateVars): string {
  return input.replace(/\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}/g, (match, key) =>
    Object.hasOwn(vars, key) ? vars[key] : match,
  )
}

/** Substitute each path segment independently (we never want `/` from a value to inject a slash). */
function substituteSegments(p: string, vars: TemplateVars): string {
  return p
    .split('/')
    .map((seg) => safeSegment(substitute(seg, vars)))
    .join('/')
}

/**
 * Reject substituted path segments that could escape the destination root —
 * a var value containing a separator or `..` would otherwise be joined
 * straight into the output path.
 */
function safeSegment(seg: string): string {
  if (seg.includes('/') || seg.includes('\\') || seg === '..') {
    throw new Error(`Template variable produced an unsafe path segment: "${seg}"`)
  }
  return seg
}
