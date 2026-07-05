# @spree/docs

Spree Commerce developer documentation packaged for local access by AI agents and development tools.

## Installation

```bash
npm install @spree/docs
# or
pnpm add @spree/docs
```

## Usage

Documentation files are plain Markdown, accessible at:

```
node_modules/@spree/docs/dist/
├── developer/
│   ├── core-concepts/     # Products, orders, payments, inventory, etc.
│   ├── customization/     # Decorators, extensions, configuration
│   ├── admin/             # Admin panel customization
│   ├── storefront/        # Storefront building guides
│   ├── sdk/               # TypeScript SDK documentation
│   ├── deployment/        # Deployment guides
│   └── tutorial/          # Step-by-step tutorials
├── api-reference/
│   └── store-api/         # Store API reference
└── integrations/          # Third-party integration guides
```

### For AI Agents

Point your `CLAUDE.md` or agent configuration to the docs:

```markdown
## Spree Documentation
Full developer docs: `node_modules/@spree/docs/dist/`
```

### Programmatic Access (Node.js)

```javascript
import { readFileSync } from 'fs'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const docsPath = require.resolve('@spree/docs/dist/developer/core-concepts/products.md')
const content = readFileSync(docsPath, 'utf-8')
```

## License

CC-BY-4.0 — same as the Spree Commerce documentation.
