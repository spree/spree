export function gitignoreContent(): string {
  return `node_modules/
.env
.env.local
.DS_Store
# Local Admin API credentials minted by \`spree api\` / \`spree auth\`
.spree/
`
}

/**
 * Build context for backend/Dockerfile (repo root): the image build ships
 * the ejected backend plus apps/dashboard, so keep the context to sources.
 * Mirrors @spree/cli's ensureRootDockerignore for pre-existing projects.
 */
export function dockerignoreContent(): string {
  return `# Build context for backend/Dockerfile (repo root): keep it to sources.
**/node_modules
**/.git
.spree
apps/storefront
apps/dashboard/dist
apps/dashboard/.tanstack
backend/log
backend/tmp
backend/storage
backend/.env*
`
}
