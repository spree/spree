// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { CustomFieldSchema } from './CustomField';

export const CategorySchema: z.ZodObject<any> = z.object({
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
  parent: z.lazy(() => CategorySchema).optional(),
  children: z.array(z.lazy(() => CategorySchema)).optional(),
  ancestors: z.array(z.lazy(() => CategorySchema)).optional(),
  custom_fields: z.array(CustomFieldSchema).optional(),
});

export type Category = z.infer<typeof CategorySchema>;
