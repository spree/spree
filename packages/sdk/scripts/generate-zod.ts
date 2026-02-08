import * as fs from 'node:fs';
import * as path from 'node:path';

const TYPES_DIR = path.resolve(import.meta.dirname, '../src/types/generated');
const ZOD_DIR = path.resolve(import.meta.dirname, '../src/zod/generated');

interface FieldDef {
  name: string;
  type: string;
  optional: boolean;
}

interface ParsedType {
  typeName: string;
  fields: FieldDef[];
}

function parseTypeFile(content: string): ParsedType | null {
  const typeNameMatch = content.match(/^type\s+(\w+)\s*=\s*\{/m);
  if (!typeNameMatch) return null;
  const typeName = typeNameMatch[1];

  const bodyMatch = content.match(/type\s+\w+\s*=\s*\{([\s\S]*?)\}/);
  if (!bodyMatch) return null;

  const body = bodyMatch[1];
  const fields: FieldDef[] = [];
  const fieldRegex = /^\s+(\w+)(\?)?\s*:\s*(.+?)\s*;?\s*$/gm;
  let match: RegExpExecArray | null;
  while ((match = fieldRegex.exec(body)) !== null) {
    fields.push({
      name: match[1],
      type: match[3].replace(/;$/, '').trim(),
      optional: match[2] === '?',
    });
  }

  return { typeName, fields };
}

function isTypeReference(typeStr: string): boolean {
  return /^[A-Z]\w+$/.test(typeStr);
}

function isPrimitive(t: string): boolean {
  return t === 'string' || t === 'number' || t === 'boolean';
}

function primitiveOrRef(inner: string, referencedTypes: Set<string>, cyclicTypes: Set<string>): string {
  if (isPrimitive(inner)) return `z.${inner}()`;
  if (isTypeReference(inner)) {
    referencedTypes.add(inner);
    if (cyclicTypes.has(inner)) {
      return `z.lazy(() => ${inner}Schema)`;
    }
    return `${inner}Schema`;
  }
  return 'z.any()';
}

function typeToZod(typeStr: string, referencedTypes: Set<string>, cyclicTypes: Set<string>): string {
  const t = typeStr.trim();

  // Record<string, unknown> | null
  if (/^Record<string,\s*unknown>\s*\|\s*null$/.test(t)) {
    return 'z.record(z.string(), z.unknown()).nullable()';
  }
  if (/^Record<string,\s*unknown>$/.test(t)) {
    return 'z.record(z.string(), z.unknown())';
  }
  if (t === 'any') return 'z.any()';

  // Array<T> | null
  const arrayNullableMatch = t.match(/^Array<(.+)>\s*\|\s*null$/);
  if (arrayNullableMatch) {
    return `z.array(${primitiveOrRef(arrayNullableMatch[1].trim(), referencedTypes, cyclicTypes)}).nullable()`;
  }

  // Array<T>
  const arrayMatch = t.match(/^Array<(.+)>$/);
  if (arrayMatch) {
    return `z.array(${primitiveOrRef(arrayMatch[1].trim(), referencedTypes, cyclicTypes)})`;
  }

  // String literal unions: 'a' | 'b' | 'c'
  if (/^'[^']*'(\s*\|\s*'[^']*')+$/.test(t)) return 'z.string()';
  // String literal union | null
  if (/^'[^']*'(\s*\|\s*'[^']*')*\s*\|\s*null$/.test(t)) return 'z.string().nullable()';

  // T | null
  const nullableMatch = t.match(/^(\w+)\s*\|\s*null$/);
  if (nullableMatch) {
    const base = nullableMatch[1].trim();
    if (isPrimitive(base)) return `z.${base}().nullable()`;
    if (isTypeReference(base)) {
      referencedTypes.add(base);
      if (cyclicTypes.has(base)) {
        return `z.lazy(() => ${base}Schema).nullable()`;
      }
      return `${base}Schema.nullable()`;
    }
  }

  // Simple primitive
  if (isPrimitive(t)) return `z.${t}()`;

  // Type reference
  if (isTypeReference(t)) {
    referencedTypes.add(t);
    if (cyclicTypes.has(t)) {
      return `z.lazy(() => ${t}Schema)`;
    }
    return `${t}Schema`;
  }

  return 'z.any()';
}

function generateZodFile(parsed: ParsedType, cyclicTypes: Set<string>): string {
  const referencedTypes = new Set<string>();
  const fieldLines: string[] = [];

  for (const field of parsed.fields) {
    let zodExpr = typeToZod(field.type, referencedTypes, cyclicTypes);
    if (field.optional) zodExpr += '.optional()';
    fieldLines.push(`  ${field.name}: ${zodExpr},`);
  }

  // Don't import self-references (self-referencing types use z.lazy)
  const refImports = Array.from(referencedTypes)
    .filter((ref) => ref !== parsed.typeName)
    .sort()
    .map((ref) => `import { ${ref}Schema } from './${ref}';`);

  const isCyclic = cyclicTypes.has(parsed.typeName);

  // For cyclic types, add explicit type annotation to break circular inference
  const schemaDecl = isCyclic
    ? `export const ${parsed.typeName}Schema: z.ZodObject<any> = z.object({`
    : `export const ${parsed.typeName}Schema = z.object({`;

  const lines: string[] = [
    '// This file is auto-generated. Do not edit directly.',
    "import { z } from 'zod';",
    ...refImports,
    '',
    schemaDecl,
    ...fieldLines,
    '});',
    '',
    `export type ${parsed.typeName} = z.infer<typeof ${parsed.typeName}Schema>;`,
    '',
  ];

  return lines.join('\n');
}

/** Extract type references from field types */
function extractTypeRefs(fields: FieldDef[]): Set<string> {
  const refs = new Set<string>();
  for (const field of fields) {
    const t = field.type.trim();
    // Array<T>
    const arrayMatch = t.match(/Array<(\w+)>/);
    if (arrayMatch && isTypeReference(arrayMatch[1])) refs.add(arrayMatch[1]);
    // T | null
    const nullableMatch = t.match(/^(\w+)\s*\|\s*null$/);
    if (nullableMatch && isTypeReference(nullableMatch[1])) refs.add(nullableMatch[1]);
    // Plain T
    if (isTypeReference(t)) refs.add(t);
  }
  return refs;
}

/** Detect all types involved in circular dependencies */
function detectCyclicTypes(parsedTypes: Map<string, ParsedType>): Set<string> {
  const deps = new Map<string, Set<string>>();
  for (const [name, parsed] of parsedTypes) {
    deps.set(name, extractTypeRefs(parsed.fields));
  }

  const cyclic = new Set<string>();
  const visited = new Set<string>();
  const inStack = new Set<string>();

  function dfs(node: string, path: string[]): void {
    if (inStack.has(node)) {
      // Found a cycle — mark all nodes in the cycle
      const cycleStart = path.indexOf(node);
      for (let i = cycleStart; i < path.length; i++) {
        cyclic.add(path[i]);
      }
      return;
    }
    if (visited.has(node)) return;

    visited.add(node);
    inStack.add(node);
    path.push(node);

    for (const dep of deps.get(node) ?? []) {
      if (deps.has(dep)) {
        dfs(dep, path);
      }
    }

    path.pop();
    inStack.delete(node);
  }

  for (const name of deps.keys()) {
    dfs(name, []);
  }

  return cyclic;
}

function main(): void {
  if (fs.existsSync(ZOD_DIR)) {
    fs.rmSync(ZOD_DIR, { recursive: true });
  }
  fs.mkdirSync(ZOD_DIR, { recursive: true });

  const files = fs
    .readdirSync(TYPES_DIR)
    .filter((f) => f.endsWith('.ts') && f !== 'index.ts')
    .sort();

  // First pass: parse all type files
  const parsedTypes = new Map<string, ParsedType>();
  for (const file of files) {
    const filePath = path.join(TYPES_DIR, file);
    const content = fs.readFileSync(filePath, 'utf-8');
    const parsed = parseTypeFile(content);
    if (!parsed) {
      console.warn(`Skipping ${file}: could not parse type definition`);
      continue;
    }
    parsedTypes.set(parsed.typeName, parsed);
  }

  // Detect cycles
  const cyclicTypes = detectCyclicTypes(parsedTypes);
  if (cyclicTypes.size > 0) {
    console.log(`Detected circular dependencies: ${Array.from(cyclicTypes).join(', ')}`);
    console.log('Using z.lazy() for these references.\n');
  }

  const generatedNames: string[] = [];

  for (const [, parsed] of parsedTypes) {
    fs.writeFileSync(
      path.join(ZOD_DIR, `${parsed.typeName}.ts`),
      generateZodFile(parsed, cyclicTypes),
      'utf-8'
    );
    generatedNames.push(parsed.typeName);
    console.log(`Generated: ${parsed.typeName}.ts`);
  }

  const indexLines = [
    '// This file is auto-generated. Do not edit directly.',
    ...generatedNames.map((n) => `export { ${n}Schema, type ${n} } from './${n}';`),
    '',
  ];
  fs.writeFileSync(path.join(ZOD_DIR, 'index.ts'), indexLines.join('\n'), 'utf-8');
  console.log(`\nGenerated barrel: index.ts (${generatedNames.length} schemas)`);
}

main();
