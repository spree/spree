/**
 * Generates admin-client.ts from the Admin API OpenAPI spec (admin.yaml).
 *
 * Usage: tsx scripts/generate-admin-client.ts
 *
 * Reads:  docs/api-reference/admin.yaml
 * Writes: src/admin-client.ts
 *
 * The generated client follows the same patterns as the hand-written store-client.ts:
 *   - Namespace-based: client.admin.products.list(), client.admin.products.get(id)
 *   - Uses RequestFn, PaginatedResponse<T>, RequestOptions from request.ts
 *   - Uses Typelizer-generated Admin* types for response typing
 *   - Generates request param interfaces for create/update bodies
 */

import * as fs from 'node:fs';
import * as path from 'node:path';

// ---------------------------------------------------------------------------
// YAML Parser (minimal, no dependency)
// ---------------------------------------------------------------------------

/** Dead-simple YAML-to-JSON for the subset rswag produces. */
function parseYaml(text: string): unknown {
  // Use JSON via js-yaml if available, otherwise fall back to line-by-line
  // Since we don't want extra deps, we shell out to node's built-in YAML support
  // Actually, Node 18+ doesn't have built-in YAML. Let's do a minimal parser.
  // The rswag output is simple enough: no anchors, no multi-doc, no flow style.

  const lines = text.split('\n');
  const root: Record<string, unknown> = {};
  const stack: { indent: number; obj: Record<string, unknown> | unknown[] }[] = [
    { indent: -1, obj: root },
  ];

  function currentContainer() {
    return stack[stack.length - 1];
  }

  function setValue(container: Record<string, unknown> | unknown[], key: string | null, value: unknown) {
    if (Array.isArray(container)) {
      container.push(value);
    } else if (key) {
      container[key] = value;
    }
  }

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    if (raw.trimStart().startsWith('#') || raw.trim() === '' || raw.trim() === '---') continue;

    const indent = raw.search(/\S/);
    const trimmed = raw.trim();

    // Pop stack to find parent
    while (stack.length > 1 && indent <= currentContainer().indent) {
      stack.pop();
    }

    const isArrayItem = trimmed.startsWith('- ');
    const content = isArrayItem ? trimmed.slice(2).trim() : trimmed;

    if (isArrayItem) {
      // Ensure parent value is an array
      const parent = currentContainer();
      // The parent's current value should be an array
      // If the content is "key: value", it's an object in the array
      if (content.includes(': ')) {
        const obj: Record<string, unknown> = {};
        const [k, ...rest] = content.split(': ');
        const v = rest.join(': ').trim();
        obj[k.trim()] = parseScalar(v);
        if (Array.isArray(parent.obj)) {
          parent.obj.push(obj);
        }
        stack.push({ indent: indent + 2, obj });
      } else {
        if (Array.isArray(parent.obj)) {
          parent.obj.push(parseScalar(content));
        }
      }
      continue;
    }

    // key: value or key:
    const colonIdx = content.indexOf(':');
    if (colonIdx === -1) continue;

    const key = content.slice(0, colonIdx).trim();
    const rawValue = content.slice(colonIdx + 1).trim();

    if (rawValue === '' || rawValue === '|' || rawValue === '>') {
      // Nested object or block scalar
      if (rawValue === '|' || rawValue === '>') {
        // Block scalar — collect indented lines
        const blockLines: string[] = [];
        const blockIndent = indent + 2;
        while (i + 1 < lines.length) {
          const nextLine = lines[i + 1];
          const nextIndent = nextLine.search(/\S/);
          if (nextIndent >= blockIndent || nextLine.trim() === '') {
            blockLines.push(nextLine.slice(blockIndent));
            i++;
          } else {
            break;
          }
        }
        const text = blockLines.join(rawValue === '|' ? '\n' : ' ').trim();
        setValue(currentContainer().obj, key, text);
      } else {
        // Check if next line starts with '- ' (array)
        const nextLine = lines[i + 1]?.trim();
        const child: Record<string, unknown> | unknown[] = nextLine?.startsWith('- ') ? [] : {};
        setValue(currentContainer().obj, key, child);
        stack.push({ indent, obj: child });
      }
    } else {
      setValue(currentContainer().obj, key, parseScalar(rawValue));
    }
  }

  return root;
}

function parseScalar(s: string): unknown {
  if (s === 'true') return true;
  if (s === 'false') return false;
  if (s === 'null') return null;
  if (/^-?\d+$/.test(s)) return parseInt(s, 10);
  if (/^-?\d+\.\d+$/.test(s)) return parseFloat(s);
  // Strip quotes
  if ((s.startsWith("'") && s.endsWith("'")) || (s.startsWith('"') && s.endsWith('"'))) {
    return s.slice(1, -1);
  }
  return s;
}

// ---------------------------------------------------------------------------
// OpenAPI types (just what we need)
// ---------------------------------------------------------------------------

interface OpenApiSpec {
  paths: Record<string, Record<string, OpenApiOperation>>;
  components?: { schemas?: Record<string, unknown> };
  tags?: Array<{ name: string; description?: string }>;
}

interface OpenApiOperation {
  summary?: string;
  description?: string;
  tags?: string[];
  parameters?: OpenApiParameter[];
  requestBody?: {
    content?: Record<string, { schema?: OpenApiSchema }>;
  };
  responses?: Record<string, { description?: string; content?: Record<string, { schema?: OpenApiSchema }> }>;
}

interface OpenApiParameter {
  name: string;
  in: string;
  required?: boolean;
  description?: string;
  schema?: OpenApiSchema;
}

interface OpenApiSchema {
  type?: string;
  properties?: Record<string, OpenApiSchema>;
  items?: OpenApiSchema;
  required?: string[];
  $ref?: string;
  enum?: unknown[];
  nullable?: boolean;
  description?: string;
  example?: unknown;
}

// ---------------------------------------------------------------------------
// Path analysis
// ---------------------------------------------------------------------------

interface ResourceEndpoint {
  method: string; // GET, POST, PATCH, DELETE
  path: string;
  operation: OpenApiOperation;
  action: 'list' | 'get' | 'create' | 'update' | 'delete' | 'custom';
  customAction?: string;
}

interface Resource {
  /** e.g. 'products', 'option_types' */
  name: string;
  /** e.g. 'Products' — from tag */
  tag: string;
  /** The base path for this resource, e.g. '/api/v3/admin/products' */
  basePath: string;
  /** Parent resource name if nested, e.g. 'products' for variants */
  parentName?: string;
  /** Parent path param, e.g. 'product_id' */
  parentParam?: string;
  endpoints: ResourceEndpoint[];
}

const API_PREFIX = '/api/v3/admin';

function classifyAction(method: string, path: string, basePath: string): { action: ResourceEndpoint['action']; customAction?: string } {
  const relative = path.slice(basePath.length);

  if (method === 'GET' && (relative === '' || relative === '/')) return { action: 'list' };
  if (method === 'GET' && relative === '/{id}') return { action: 'get' };
  if (method === 'POST' && (relative === '' || relative === '/')) return { action: 'create' };
  if (method === 'PATCH' && relative === '/{id}') return { action: 'update' };
  if (method === 'PUT' && relative === '/{id}') return { action: 'update' };
  if (method === 'DELETE' && relative === '/{id}') return { action: 'delete' };

  // Custom actions like POST /products/{id}/clone
  const customMatch = relative.match(/^\/{id}\/(\w+)$/);
  if (customMatch) return { action: 'custom', customAction: customMatch[1] };

  // Member-less custom: POST /products/import
  const rootCustom = relative.match(/^\/(\w+)$/);
  if (rootCustom) return { action: 'custom', customAction: rootCustom[1] };

  return { action: 'custom', customAction: relative.replace(/[{}\/]/g, '_').replace(/^_+|_+$/g, '') };
}

function analyzeResources(spec: OpenApiSpec): Resource[] {
  const resourceMap = new Map<string, Resource>();

  for (const [fullPath, methods] of Object.entries(spec.paths)) {
    if (!fullPath.startsWith(API_PREFIX)) continue;

    const apiPath = fullPath.slice(API_PREFIX.length); // e.g. '/products', '/products/{id}'

    for (const [method, operation] of Object.entries(methods)) {
      if (!operation || typeof operation !== 'object') continue;
      const httpMethod = method.toUpperCase();
      if (!['GET', 'POST', 'PATCH', 'PUT', 'DELETE'].includes(httpMethod)) continue;

      const tag = operation.tags?.[0] || 'Unknown';

      // Determine resource name and nesting
      // /products → resource=products
      // /products/{id} → resource=products
      // /products/{product_id}/variants → resource=variants, parent=products
      // /products/{product_id}/variants/{id} → resource=variants, parent=products
      const segments = apiPath.split('/').filter(Boolean);

      let resourceName: string;
      let basePath: string;
      let parentName: string | undefined;
      let parentParam: string | undefined;

      if (segments.length >= 3 && segments[1].startsWith('{') && segments[1].endsWith('}')) {
        // Check if this is a member action (e.g., /orders/{id}/cancel) vs a nested resource
        // Member actions: only have /parent/{id}/action (no further /{id})
        // Nested resources: have /parent/{id}/resource and /parent/{id}/resource/{id}
        const isMemberAction = segments.length === 3 && !segments[2].startsWith('{');

        // Look ahead: is there a collection endpoint for this sub-path?
        // If there's only single-verb endpoints and no collection/show patterns, treat as member action
        const subPathPrefix = `${API_PREFIX}/${segments[0]}/${segments[1]}/${segments[2]}`;
        const hasCollectionOrMember = Object.keys(spec.paths).some(
          (p) => p.startsWith(subPathPrefix) && p !== fullPath && p.includes('/{id}')
        );
        const hasCollectionEndpoint = Object.keys(spec.paths).some(
          (p) => p === subPathPrefix && spec.paths[p]?.get
        );

        if (isMemberAction && !hasCollectionOrMember && !hasCollectionEndpoint) {
          // This is a member action on the parent resource (e.g., PATCH /orders/{id}/cancel)
          resourceName = segments[0];
          basePath = `${API_PREFIX}/${segments[0]}`;
          // Classify as a custom action on the parent resource
        } else {
          // Nested resource: /products/{product_id}/variants...
          parentName = segments[0];
          parentParam = segments[1].slice(1, -1); // remove { }
          resourceName = segments[2];
          basePath = `${API_PREFIX}/${segments[0]}/${segments[1]}/${segments[2]}`;
        }
      } else {
        resourceName = segments[0];
        basePath = `${API_PREFIX}/${segments[0]}`;
      }

      const resourceKey = parentName ? `${parentName}.${resourceName}` : resourceName;
      const { action, customAction } = classifyAction(httpMethod, fullPath, basePath);

      if (!resourceMap.has(resourceKey)) {
        resourceMap.set(resourceKey, {
          name: resourceName,
          tag,
          basePath,
          parentName,
          parentParam,
          endpoints: [],
        });
      }

      resourceMap.get(resourceKey)!.endpoints.push({
        method: httpMethod,
        path: fullPath,
        operation,
        action,
        customAction,
      });
    }
  }

  return Array.from(resourceMap.values());
}

// ---------------------------------------------------------------------------
// Type name helpers
// ---------------------------------------------------------------------------

/** 'products' → 'Product', 'option_types' → 'OptionType' */
function singularPascal(name: string): string {
  // Handle snake_case
  const pascal = name
    .split('_')
    .map((s) => s.charAt(0).toUpperCase() + s.slice(1))
    .join('');

  // Simple singularization
  if (pascal.endsWith('ies')) return pascal.slice(0, -3) + 'y';
  if (pascal.endsWith('ses')) return pascal.slice(0, -2);
  if (pascal.endsWith('s')) return pascal.slice(0, -1);
  return pascal;
}

/** 'option_types' → 'optionTypes' */
function camelCase(name: string): string {
  return name.replace(/_(\w)/g, (_, c) => c.toUpperCase());
}

function getResponseType(resource: Resource): string {
  return `Admin${singularPascal(resource.name)}`;
}

// ---------------------------------------------------------------------------
// Request body type generation
// ---------------------------------------------------------------------------

function schemaToTsType(schema: OpenApiSchema, indent = 2): string {
  if (schema.$ref) {
    const refName = schema.$ref.split('/').pop()!;
    return refName;
  }

  if (schema.type === 'string') {
    if (schema.enum) return schema.enum.map((e) => `'${e}'`).join(' | ');
    return 'string';
  }
  if (schema.type === 'number' || schema.type === 'integer') return 'number';
  if (schema.type === 'boolean') return 'boolean';

  if (schema.type === 'array' && schema.items) {
    const itemType = schemaToTsType(schema.items, indent);
    return `Array<${itemType}>`;
  }

  if (schema.type === 'object' && schema.properties) {
    const required = new Set(schema.required || []);
    const pad = ' '.repeat(indent);
    const lines = Object.entries(schema.properties).map(([key, prop]) => {
      const opt = required.has(key) ? '' : '?';
      const type = schemaToTsType(prop as OpenApiSchema, indent + 2);
      return `${pad}${key}${opt}: ${type};`;
    });
    return `{\n${lines.join('\n')}\n${' '.repeat(indent - 2)}}`;
  }

  return 'unknown';
}

function generateRequestParamType(
  resource: Resource,
  action: 'create' | 'update',
  operation: OpenApiOperation
): { typeName: string; typeBody: string } | null {
  // Find request body schema
  const bodyParam = operation.parameters?.find((p) => p.name === 'body' && p.in === 'body');
  const bodySchema = (bodyParam as unknown as { schema?: OpenApiSchema })?.schema;

  // Also check requestBody (OpenAPI 3.0 style)
  const requestBodySchema =
    operation.requestBody?.content?.['application/json']?.schema;

  const schema = bodySchema || requestBodySchema;
  if (!schema?.properties) return null;

  const typeName = `Admin${singularPascal(resource.name)}${action === 'create' ? 'Create' : 'Update'}Params`;
  const typeBody = schemaToTsType(schema);

  return { typeName, typeBody };
}

// ---------------------------------------------------------------------------
// Code generation
// ---------------------------------------------------------------------------

function generateResourceMethods(resource: Resource, paramTypes: Map<string, string>): string {
  const lines: string[] = [];
  const responseType = getResponseType(resource);
  const hasParent = !!resource.parentName;
  const parentParamName = resource.parentParam ? camelCase(resource.parentParam) : '';

  for (const endpoint of resource.endpoints) {
    const { action, method, operation, customAction } = endpoint;

    const summary = operation.summary || '';
    const jsdoc = summary ? `    /** ${summary} */` : '';

    switch (action) {
      case 'list': {
        if (jsdoc) lines.push(jsdoc);
        if (hasParent) {
          lines.push(`    list: (`);
          lines.push(`      ${parentParamName}: string,`);
          lines.push(`      params?: ListParams,`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<PaginatedResponse<${responseType}>> =>`);
          lines.push(`      this.request<PaginatedResponse<${responseType}>>('GET', \`/${resource.parentName}/\${${parentParamName}}/${resource.name}\`, {`);
          lines.push(`        ...options,`);
          lines.push(`        params: transformListParams({ ...params }),`);
          lines.push(`      }),`);
        } else {
          lines.push(`    list: (`);
          lines.push(`      params?: ListParams,`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<PaginatedResponse<${responseType}>> =>`);
          lines.push(`      this.request<PaginatedResponse<${responseType}>>('GET', '/${resource.name}', {`);
          lines.push(`        ...options,`);
          lines.push(`        params: transformListParams({ ...params }),`);
          lines.push(`      }),`);
        }
        break;
      }

      case 'get': {
        if (jsdoc) lines.push(jsdoc);
        if (hasParent) {
          lines.push(`    get: (`);
          lines.push(`      ${parentParamName}: string,`);
          lines.push(`      id: string,`);
          lines.push(`      params?: { expand?: string[] },`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<${responseType}> =>`);
          lines.push(`      this.request<${responseType}>('GET', \`/${resource.parentName}/\${${parentParamName}}/${resource.name}/\${id}\`, {`);
          lines.push(`        ...options,`);
          lines.push(`        params: getParams(params),`);
          lines.push(`      }),`);
        } else {
          lines.push(`    get: (`);
          lines.push(`      id: string,`);
          lines.push(`      params?: { expand?: string[] },`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<${responseType}> =>`);
          lines.push(`      this.request<${responseType}>('GET', \`/${resource.name}/\${id}\`, {`);
          lines.push(`        ...options,`);
          lines.push(`        params: getParams(params),`);
          lines.push(`      }),`);
        }
        break;
      }

      case 'create': {
        const createTypeName = `Admin${singularPascal(resource.name)}CreateParams`;
        const paramType = paramTypes.has(createTypeName) ? createTypeName : 'Record<string, unknown>';
        if (jsdoc) lines.push(jsdoc);
        if (hasParent) {
          lines.push(`    create: (`);
          lines.push(`      ${parentParamName}: string,`);
          lines.push(`      params: ${paramType},`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<${responseType}> =>`);
          lines.push(`      this.request<${responseType}>('POST', \`/${resource.parentName}/\${${parentParamName}}/${resource.name}\`, {`);
          lines.push(`        ...options,`);
          lines.push(`        body: params,`);
          lines.push(`      }),`);
        } else {
          lines.push(`    create: (`);
          lines.push(`      params: ${paramType},`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<${responseType}> =>`);
          lines.push(`      this.request<${responseType}>('POST', '/${resource.name}', {`);
          lines.push(`        ...options,`);
          lines.push(`        body: params,`);
          lines.push(`      }),`);
        }
        break;
      }

      case 'update': {
        const updateTypeName = `Admin${singularPascal(resource.name)}UpdateParams`;
        const paramType = paramTypes.has(updateTypeName) ? updateTypeName : 'Record<string, unknown>';
        if (jsdoc) lines.push(jsdoc);
        if (hasParent) {
          lines.push(`    update: (`);
          lines.push(`      ${parentParamName}: string,`);
          lines.push(`      id: string,`);
          lines.push(`      params: ${paramType},`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<${responseType}> =>`);
          lines.push(`      this.request<${responseType}>('PATCH', \`/${resource.parentName}/\${${parentParamName}}/${resource.name}/\${id}\`, {`);
          lines.push(`        ...options,`);
          lines.push(`        body: params,`);
          lines.push(`      }),`);
        } else {
          lines.push(`    update: (`);
          lines.push(`      id: string,`);
          lines.push(`      params: ${paramType},`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<${responseType}> =>`);
          lines.push(`      this.request<${responseType}>('PATCH', \`/${resource.name}/\${id}\`, {`);
          lines.push(`        ...options,`);
          lines.push(`        body: params,`);
          lines.push(`      }),`);
        }
        break;
      }

      case 'delete': {
        if (jsdoc) lines.push(jsdoc);
        if (hasParent) {
          lines.push(`    delete: (`);
          lines.push(`      ${parentParamName}: string,`);
          lines.push(`      id: string,`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<void> =>`);
          lines.push(`      this.request<void>('DELETE', \`/${resource.parentName}/\${${parentParamName}}/${resource.name}/\${id}\`, options),`);
        } else {
          lines.push(`    delete: (`);
          lines.push(`      id: string,`);
          lines.push(`      options?: RequestOptions`);
          lines.push(`    ): Promise<void> =>`);
          lines.push(`      this.request<void>('DELETE', \`/${resource.name}/\${id}\`, options),`);
        }
        break;
      }

      case 'custom': {
        if (!customAction) break;
        const fnName = camelCase(customAction);
        if (jsdoc) lines.push(jsdoc);
        // Custom actions are always on a member (POST /resources/{id}/action)
        if (method === 'POST' || method === 'PATCH') {
          if (hasParent) {
            lines.push(`    ${fnName}: (`);
            lines.push(`      ${parentParamName}: string,`);
            lines.push(`      id: string,`);
            lines.push(`      params?: Record<string, unknown>,`);
            lines.push(`      options?: RequestOptions`);
            lines.push(`    ): Promise<${responseType}> =>`);
            lines.push(`      this.request<${responseType}>('${method}', \`/${resource.parentName}/\${${parentParamName}}/${resource.name}/\${id}/${customAction}\`, {`);
            lines.push(`        ...options,`);
            lines.push(`        body: params,`);
            lines.push(`      }),`);
          } else {
            lines.push(`    ${fnName}: (`);
            lines.push(`      id: string,`);
            lines.push(`      params?: Record<string, unknown>,`);
            lines.push(`      options?: RequestOptions`);
            lines.push(`    ): Promise<${responseType}> =>`);
            lines.push(`      this.request<${responseType}>('${method}', \`/${resource.name}/\${id}/${customAction}\`, {`);
            lines.push(`        ...options,`);
            lines.push(`        body: params,`);
            lines.push(`      }),`);
          }
        }
        break;
      }
    }

    lines.push('');
  }

  return lines.join('\n');
}

function generateParamsFile(paramTypes: Map<string, string>): string {
  const out: string[] = [];

  out.push(`// This file is auto-generated by scripts/generate-admin-client.ts`);
  out.push(`// Do not edit manually. Run: npm run generate:admin-client`);
  out.push(``);
  out.push(`// Request parameter types (generated from OpenAPI request bodies)`);
  out.push(``);

  for (const [name, body] of paramTypes) {
    out.push(`export interface ${name} ${body}`);
    out.push(``);
  }

  return out.join('\n');
}

function generateClient(spec: OpenApiSpec): { client: string; params: string } {
  const resources = analyzeResources(spec);

  // Collect all param types from request bodies
  const paramTypes = new Map<string, string>();
  for (const resource of resources) {
    for (const endpoint of resource.endpoints) {
      if (endpoint.action === 'create' || endpoint.action === 'update') {
        const result = generateRequestParamType(resource, endpoint.action, endpoint.operation);
        if (result) {
          paramTypes.set(result.typeName, result.typeBody);
        }
      }
    }
  }

  // Collect all response types used
  const responseTypes = new Set<string>();
  for (const resource of resources) {
    responseTypes.add(getResponseType(resource));
  }

  // Group resources: top-level vs nested
  const topLevel = resources.filter((r) => !r.parentName);
  const nested = resources.filter((r) => r.parentName);

  // Build imports
  const importedTypes = [...responseTypes].sort();
  const paramTypeNames = [...paramTypes.keys()].sort();

  // Build client output
  const out: string[] = [];

  out.push(`// This file is auto-generated by scripts/generate-admin-client.ts`);
  out.push(`// Do not edit manually. Run: npm run generate:admin-client`);
  out.push(``);
  out.push(`import type { RequestFn, RequestOptions } from './request';`);
  out.push(`import { transformListParams } from './params';`);
  out.push(`import type {`);
  out.push(`  PaginatedResponse,`);
  out.push(`  ListParams,`);
  for (const t of importedTypes) {
    out.push(`  ${t},`);
  }
  out.push(`} from './types';`);

  // Import param types from admin-params
  if (paramTypeNames.length > 0) {
    out.push(`import type {`);
    for (const name of paramTypeNames) {
      out.push(`  ${name},`);
    }
    out.push(`} from './admin-params';`);
  }

  out.push(``);

  // Re-export param types so consumers can import from either file
  if (paramTypeNames.length > 0) {
    out.push(`export type {`);
    for (const name of paramTypeNames) {
      out.push(`  ${name},`);
    }
    out.push(`} from './admin-params';`);
    out.push(``);
  }

  // Helper
  out.push(`/** Serialize expand arrays into comma-separated query params */`);
  out.push(`function getParams(params?: { expand?: string[] }): Record<string, string> | undefined {`);
  out.push(`  if (!params?.expand?.length) return undefined;`);
  out.push(`  return { expand: params.expand.join(',') };`);
  out.push(`}`);
  out.push(``);

  // Class
  out.push(`export class AdminClient {`);
  out.push(`  private readonly request: RequestFn;`);
  out.push(``);
  out.push(`  constructor(request: RequestFn) {`);
  out.push(`    this.request = request;`);
  out.push(`  }`);

  // Top-level resources
  for (const resource of topLevel) {
    const propName = camelCase(resource.name);
    const nestedResources = nested.filter((n) => n.parentName === resource.name);

    out.push(``);
    out.push(`  // ============================================`);
    out.push(`  // ${resource.tag}`);
    out.push(`  // ============================================`);
    out.push(``);
    out.push(`  readonly ${propName} = {`);
    out.push(generateResourceMethods(resource, paramTypes));

    // Add nested resources as sub-objects
    for (const nestedResource of nestedResources) {
      const nestedPropName = camelCase(nestedResource.name);
      out.push(`    /** Nested: ${resource.name}/{id}/${nestedResource.name} */`);
      out.push(`    ${nestedPropName}: {`);
      // Indent nested methods by 2 more spaces
      const nestedMethods = generateResourceMethods(nestedResource, paramTypes)
        .split('\n')
        .map((line) => (line.trim() ? `  ${line}` : line))
        .join('\n');
      out.push(nestedMethods);
      out.push(`    },`);
      out.push(``);
    }

    out.push(`  };`);
  }

  // Any orphan nested resources (parent not in spec yet)
  const orphanNested = nested.filter(
    (n) => !topLevel.some((t) => t.name === n.parentName)
  );
  for (const resource of orphanNested) {
    const propName = `${camelCase(resource.parentName!)}${singularPascal(resource.name).replace(/s$/, '')}s`;
    out.push(``);
    out.push(`  // ============================================`);
    out.push(`  // ${resource.tag} (nested under ${resource.parentName})`);
    out.push(`  // ============================================`);
    out.push(``);
    out.push(`  readonly ${propName} = {`);
    out.push(generateResourceMethods(resource, paramTypes));
    out.push(`  };`);
  }

  out.push(`}`);
  out.push(``);

  return {
    client: out.join('\n'),
    params: generateParamsFile(paramTypes),
  };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const SPEC_PATH = path.resolve(import.meta.dirname, '../../../docs/api-reference/admin.yaml');
const OUTPUT_PATH = path.resolve(import.meta.dirname, '../src/admin-client.ts');
const PARAMS_PATH = path.resolve(import.meta.dirname, '../src/admin-params.ts');

if (!fs.existsSync(SPEC_PATH)) {
  console.error(`Admin API spec not found at: ${SPEC_PATH}`);
  console.error('Run `bundle exec rake rswag:specs:swaggerize` first to generate it.');
  process.exit(1);
}

console.log(`Reading: ${SPEC_PATH}`);
const yamlContent = fs.readFileSync(SPEC_PATH, 'utf-8');

// Use a proper YAML parser — try to import js-yaml or yaml, fall back to JSON conversion via CLI
let spec: OpenApiSpec;
try {
  // Try dynamic import of yaml (common in Node projects)
  const yamlModule = await import('yaml');
  spec = yamlModule.parse(yamlContent) as OpenApiSpec;
} catch {
  try {
    // Try js-yaml
    const jsYaml = await import('js-yaml');
    spec = jsYaml.load(yamlContent) as OpenApiSpec;
  } catch {
    // Last resort: use our minimal parser
    console.warn('No YAML parser found (yaml or js-yaml). Using minimal built-in parser.');
    spec = parseYaml(yamlContent) as OpenApiSpec;
  }
}

const { client, params } = generateClient(spec);

fs.writeFileSync(PARAMS_PATH, params, 'utf-8');
console.log(`Generated: ${PARAMS_PATH}`);

fs.writeFileSync(OUTPUT_PATH, client, 'utf-8');
console.log(`Generated: ${OUTPUT_PATH}`);

// Summary
const resources = analyzeResources(spec);
console.log(`\nResources (${resources.length}):`);
for (const r of resources) {
  const prefix = r.parentName ? `  └─ ${r.parentName}/{id}/` : '  ';
  console.log(`${prefix}${r.name} (${r.endpoints.map((e) => `${e.method} ${e.action}`).join(', ')})`);
}
