import * as fs from 'node:fs'
import * as path from 'node:path'
import { parse } from 'yaml'
import { type FilterSpec, renderFilterTypes } from '../src/filter-types'

// Runs from the SDK package being generated (its `generate:filters` script),
// reading that SDK's API reference and writing its list filter types:
//
//   tsx ../sdk-core/scripts/generate-filters.ts admin

const api = process.argv[2]
if (!api) throw new Error('Usage: generate-filters.ts <store|admin|seller>')

const specPath = path.resolve(process.cwd(), `../../docs/api-reference/${api}.yaml`)
const outputPath = path.resolve(process.cwd(), 'src/types/filters.generated.ts')
const spec = parse(fs.readFileSync(specPath, 'utf8')) as FilterSpec

fs.writeFileSync(outputPath, renderFilterTypes(spec, api))
console.log(`Wrote ${path.relative(process.cwd(), outputPath)}`)
