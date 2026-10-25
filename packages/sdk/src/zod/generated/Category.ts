// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Category from '../../types/generated/Category';
import { CustomFieldSchema } from './CustomField';

export const CategorySchema = z.object({
  id: z.string(),
  name: z.string(),
  permalink: z.string(),
  position: z.number(),
  depth: z.number(),
  meta_title: z.string().nullable(),
  meta_description: z.string().nullable(),
  meta_keywords: z.string().nullable(),
  children_count: z.number(),
  parent_id: z.string().nullable(),
  description: z.string(),
  description_html: z.string(),
  image_url: z.string().nullable(),
  square_image_url: z.string().nullable(),
  is_root: z.boolean(),
  is_child: z.boolean(),
  is_leaf: z.boolean(),
  get parent() { return CategorySchema.optional(); },
  get children() { return z.array(CategorySchema).optional(); },
  get ancestors() { return z.array(CategorySchema).optional(); },
  custom_fields: z.array(CustomFieldSchema).optional(),
}) as unknown as z.ZodObject<{
  id: z.ZodType<Category['id']>;
  name: z.ZodType<Category['name']>;
  permalink: z.ZodType<Category['permalink']>;
  position: z.ZodType<Category['position']>;
  depth: z.ZodType<Category['depth']>;
  meta_title: z.ZodType<Category['meta_title']>;
  meta_description: z.ZodType<Category['meta_description']>;
  meta_keywords: z.ZodType<Category['meta_keywords']>;
  children_count: z.ZodType<Category['children_count']>;
  parent_id: z.ZodType<Category['parent_id']>;
  description: z.ZodType<Category['description']>;
  description_html: z.ZodType<Category['description_html']>;
  image_url: z.ZodType<Category['image_url']>;
  square_image_url: z.ZodType<Category['square_image_url']>;
  is_root: z.ZodType<Category['is_root']>;
  is_child: z.ZodType<Category['is_child']>;
  is_leaf: z.ZodType<Category['is_leaf']>;
  parent: z.ZodOptional<z.ZodType<Exclude<Category['parent'], undefined>>>;
  children: z.ZodOptional<z.ZodType<Exclude<Category['children'], undefined>>>;
  ancestors: z.ZodOptional<z.ZodType<Exclude<Category['ancestors'], undefined>>>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<Category['custom_fields'], undefined>>>;
}>;

export type { Category };
