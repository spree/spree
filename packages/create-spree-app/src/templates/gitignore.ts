export function gitignoreContent(): string {
  return `node_modules/
.env
.env.local
.DS_Store
# Local Admin API credentials minted by \`spree api\` / \`spree auth\`
.spree/
`
}
