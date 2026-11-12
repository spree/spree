import * as fs from 'node:fs'
import * as path from 'node:path'
import { parse } from 'yaml'
import { type ParamsSpec, renderParamsTypes } from '../src/params-types'

// Runs from the SDK package being generated (its `generate:params` script),
// reading that SDK's API reference and writing its request body types, one
// file per type, into src/types/params/:
//
//   tsx ../sdk-core/scripts/generate-params.ts admin

const api = process.argv[2]
if (!api) throw new Error('Usage: generate-params.ts <store|admin|seller>')

const specPath = path.resolve(process.cwd(), `../../docs/api-reference/${api}.yaml`)
const outputDir = path.resolve(process.cwd(), 'src/types/params')
const spec = parse(fs.readFileSync(specPath, 'utf8')) as ParamsSpec
const files = renderParamsTypes(spec)

// Rewritten from scratch, so a type whose endpoint went away goes with it.
fs.rmSync(outputDir, { recursive: true, force: true })
fs.mkdirSync(outputDir, { recursive: true })
for (const [name, source] of files) fs.writeFileSync(path.join(outputDir, name), source)
console.log(`Wrote ${files.size - 1} request types to ${path.relative(process.cwd(), outputDir)}/`)
