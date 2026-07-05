/**
 * Pure conversion functions for MDX → Markdown transformation.
 * Separated from build.js for testability.
 */

import { relative } from "path";

// ---------------------------------------------------------------------------
// Callout mapping
// ---------------------------------------------------------------------------

const CALLOUT_MAP = {
  Info: "INFO",
  Warning: "WARNING",
  Tip: "TIP",
  Note: "NOTE",
  Hint: "HINT",
};

// ---------------------------------------------------------------------------
// Import resolution
// ---------------------------------------------------------------------------

export function resolveImports(content, snippetResolver = () => "") {
  // Collect import mappings: import Name from '/snippets/...'
  const importMap = new Map();
  const importRegex = /^import\s+(\w+)\s+from\s+['"]([^'"]+)['"]\s*;?\s*$/gm;
  let match;

  while ((match = importRegex.exec(content)) !== null) {
    const [, componentName, importPath] = match;
    // Only resolve snippet imports (from /snippets/ or relative .mdx)
    if (importPath.includes("/snippets/") || importPath.endsWith(".mdx")) {
      importMap.set(componentName, importPath);
    }
  }

  // Remove all import lines
  content = content.replace(
    /^import\s+\w+\s+from\s+['"][^'"]+['"]\s*;?\s*$/gm,
    "",
  );

  // Replace <ComponentName /> self-closing tags with inlined snippet content
  for (const [name, path] of importMap) {
    const selfClosingRegex = new RegExp(`<${name}\\s*/>`, "g");
    const snippetContent = snippetResolver(path);
    content = content.replace(selfClosingRegex, snippetContent);
  }

  return content;
}

// ---------------------------------------------------------------------------
// Component conversion
// ---------------------------------------------------------------------------

export function convertContent(content) {
  // Protect code blocks from conversion
  const codeBlocks = [];
  content = content.replace(/(```[\s\S]*?```|`[^`\n]+`)/g, (match) => {
    const index = codeBlocks.length;
    codeBlocks.push(match);
    return `__CODE_BLOCK_${index}__`;
  });

  // --- Callout components → GitHub-style blockquote alerts ---
  for (const [component, label] of Object.entries(CALLOUT_MAP)) {
    const regex = new RegExp(
      `<${component}>\\s*([\\s\\S]*?)\\s*</${component}>`,
      "gi",
    );
    content = content.replace(regex, (_, inner) => {
      const lines = inner.trim().split("\n");
      return `> **${label}:** ${lines.join("\n> ")}`;
    });
  }

  // --- Tabs → Sections with headers ---
  content = content.replace(/<Tabs>\s*([\s\S]*?)\s*<\/Tabs>/gi, (_, inner) => {
    return inner.replace(
      /<Tab\s+title="([^"]*)">\s*([\s\S]*?)\s*<\/Tab>/gi,
      (_, title, tabContent) => {
        return `**${title}:**\n\n${tabContent.trim()}\n`;
      },
    );
  });

  // --- Steps → Numbered list ---
  let stepCounter = 0;
  content = content.replace(
    /<Steps>\s*([\s\S]*?)\s*<\/Steps>/gi,
    (_, inner) => {
      stepCounter = 0;
      return inner.replace(
        /<Step\s+title="([^"]*)">\s*([\s\S]*?)\s*<\/Step>/gi,
        (_, title, stepContent) => {
          stepCounter++;
          return `**Step ${stepCounter}: ${title}**\n\n${stepContent.trim()}\n`;
        },
      );
    },
  );

  // --- CodeGroup → Just keep the code blocks inside ---
  content = content.replace(/<\/?CodeGroup>/gi, "");

  // --- Accordion/AccordionGroup → Details/summary ---
  content = content.replace(
    /<AccordionGroup>\s*([\s\S]*?)\s*<\/AccordionGroup>/gi,
    (_, inner) => inner,
  );
  content = content.replace(
    /<Accordion\s+title="([^"]*)">\s*([\s\S]*?)\s*<\/Accordion>/gi,
    (_, title, inner) => {
      return `<details>\n<summary>${title}</summary>\n\n${inner.trim()}\n\n</details>\n`;
    },
  );

  // --- Card/CardGroup → Bold title + description ---
  content = content.replace(/<\/?CardGroup[^>]*>/gi, "");
  content = content.replace(
    /<Card\s+([^>]*)>([\s\S]*?)<\/Card>/gi,
    (_, attrs, inner) => {
      const titleMatch = attrs.match(/title="([^"]*)"/);
      const hrefMatch = attrs.match(/href="([^"]*)"/);
      const title = titleMatch ? titleMatch[1] : "";
      const href = hrefMatch ? hrefMatch[1] : "";
      const titleText = href ? `[${title}](${href})` : `**${title}**`;
      const body = inner.trim();
      return body ? `- ${titleText} — ${body}` : `- ${titleText}`;
    },
  );
  // Self-closing cards
  content = content.replace(/<Card\s+([\s\S]*?)\/>/gi, (_, attrs) => {
    const titleMatch = attrs.match(/title="([^"]*)"/);
    const hrefMatch = attrs.match(/href="([^"]*)"/);
    const title = titleMatch ? titleMatch[1] : "";
    const href = hrefMatch ? hrefMatch[1] : "";
    return href ? `- [${title}](${href})` : `- **${title}**`;
  });

  // --- Frame → Just keep the content (strip the wrapper) ---
  content = content.replace(
    /<Frame[^>]*>\s*([\s\S]*?)\s*<\/Frame>/gi,
    (_, inner) => inner.trim(),
  );

  // --- Expandable → Details/summary ---
  content = content.replace(
    /<Expandable\s+title="([^"]*)">\s*([\s\S]*?)\s*<\/Expandable>/gi,
    (_, title, inner) => {
      return `<details>\n<summary>${title}</summary>\n\n${inner.trim()}\n\n</details>\n`;
    },
  );

  // --- ResponseField → Bold field name with type ---
  content = content.replace(
    /<ResponseField\s+name="([^"]*)"\s+type="([^"]*)">\s*([\s\S]*?)\s*<\/ResponseField>/gi,
    (_, name, type, desc) => {
      return `- **\`${name}\`** (\`${type}\`) — ${desc.trim()}`;
    },
  );

  // --- ParamField → Bold param name with type ---
  content = content.replace(
    /<ParamField\s+([^>]*)>\s*([\s\S]*?)\s*<\/ParamField>/gi,
    (_, attrs, desc) => {
      const nameMatch = attrs.match(/(?:name|path|query|body)="([^"]*)"/);
      const typeMatch = attrs.match(/type="([^"]*)"/);
      const name = nameMatch ? nameMatch[1] : "";
      const type = typeMatch ? ` (\`${typeMatch[1]}\`)` : "";
      return `- **\`${name}\`**${type} — ${desc.trim()}`;
    },
  );

  // --- Icon → just remove ---
  content = content.replace(/<Icon\s[^>]*\/>/gi, "");
  content = content.replace(/<Icon\s[^>]*>[^<]*<\/Icon>/gi, "");

  // --- CopyCommand → code block ---
  content = content.replace(
    /<CopyCommand\s+command="([^"]*)"[^>]*\/>/gi,
    (_, cmd) => {
      return "```bash\n" + cmd + "\n```";
    },
  );

  // --- Columns → just keep content ---
  content = content.replace(/<\/?Columns[^>]*>/gi, "");

  // --- Any remaining self-closing custom components → remove ---
  content = content.replace(/<[A-Z]\w*\s[^>]*\/>/g, "");

  // --- Any remaining paired custom components → keep inner content ---
  content = content.replace(
    /<([A-Z]\w*)(?:\s[^>]*)?>[\s]*([\s\S]*?)[\s]*<\/\1>/g,
    (_, _tag, inner) => inner.trim(),
  );

  // --- Clean up: remove excessive blank lines ---
  content = content.replace(/\n{4,}/g, "\n\n\n");

  // --- Restore code blocks ---
  content = content.replace(
    /__CODE_BLOCK_(\d+)__/g,
    (_, index) => codeBlocks[parseInt(index)],
  );

  return content;
}

// ---------------------------------------------------------------------------
// Frontmatter handling
// ---------------------------------------------------------------------------

export function extractFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) return { frontmatter: null, body: content };
  return { frontmatter: match[0], body: content.slice(match[0].length) };
}

// ---------------------------------------------------------------------------
// Link rewriting
// ---------------------------------------------------------------------------

export function rewriteLinks(content, fileRelDir) {
  return content.replace(
    /\[([^\]]*)\]\(\/(developer|api-reference|integrations)(\/[^)]*)\)/g,
    (match, text, prefix, rest) => {
      const [pathPart, anchor] = rest.split("#", 2);
      const targetPath = prefix + pathPart;
      const relPath = relative(fileRelDir, targetPath) || ".";
      const suffix = anchor ? `#${anchor}` : "";
      return `[${text}](${relPath}.md${suffix})`;
    },
  );
}
