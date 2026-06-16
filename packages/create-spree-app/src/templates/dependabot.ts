interface Ecosystem {
  comment: string
  ecosystem: string
  directory: string
  /** Group-name prefix, unique per block (group names must be unique). */
  group: string
}

/**
 * Renders one `updates:` entry. Security and version updates are each bundled
 * into a single grouped PR per ecosystem (`applies-to`), so a weekly run opens
 * at most one security PR and one version PR instead of one per package.
 */
function ecosystemBlock({ comment, ecosystem, directory, group }: Ecosystem): string {
  return `  # ${comment}
  - package-ecosystem: ${ecosystem}
    directory: "${directory}"
    schedule:
      interval: weekly
    open-pull-requests-limit: 5
    groups:
      ${group}-security:
        applies-to: security-updates
        patterns:
          - "*"
      ${group}-version:
        applies-to: version-updates
        patterns:
          - "*"`
}

/**
 * Dependabot config for a generated project. Covers each package ecosystem in
 * the scaffold: the npm wrapper at the root, the Rails backend gems, GitHub
 * Actions, and — when included — the Next.js storefront. Dockerfile base
 * images are intentionally left out: the backend runs a prebuilt image until
 * `spree eject`, and the base tags are pinned via ARG defaults.
 *
 * Security updates additionally require the "Dependabot security updates"
 * toggle in the repo's Settings → Advanced Security; the config only groups
 * them.
 */
export function dependabotContent(hasStorefront: boolean): string {
  const ecosystems: Ecosystem[] = [
    {
      comment: 'Root wrapper (@spree/cli, @spree/docs)',
      ecosystem: 'npm',
      directory: '/',
      group: 'root',
    },
    {
      comment: 'Rails backend gems',
      ecosystem: 'bundler',
      directory: '/backend',
      group: 'backend',
    },
    {
      comment: 'CI workflows',
      ecosystem: 'github-actions',
      directory: '/',
      group: 'actions',
    },
  ]

  if (hasStorefront) {
    ecosystems.push({
      comment: 'Next.js storefront',
      ecosystem: 'npm',
      directory: '/apps/storefront',
      group: 'storefront',
    })
  }

  return `version: 2
updates:
${ecosystems.map(ecosystemBlock).join('\n\n')}
`
}
