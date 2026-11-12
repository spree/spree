// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type OptionType from '../../types/generated/OptionType';
import { CustomFieldSchema } from './CustomField';
import { OptionValueSchema } from './OptionValue';

export const OptionTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  kind: z.string(),
  custom_fields: z.array(CustomFieldSchema).optional(),
  translations: z.record(z.string(), z.record(z.string(), z.union([z.string(), z.number()]).nullable())).optional(),
  metadata: z.record(z.string(), z.unknown()),
  filterable: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  get option_values() { return z.array(OptionValueSchema).optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<OptionType['id']>;
  name: z.ZodType<OptionType['name']>;
  label: z.ZodType<OptionType['label']>;
  position: z.ZodType<OptionType['position']>;
  kind: z.ZodType<OptionType['kind']>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<OptionType['custom_fields'], undefined>>>;
  translations: z.ZodOptional<z.ZodType<Exclude<OptionType['translations'], undefined>>>;
  metadata: z.ZodType<OptionType['metadata']>;
  filterable: z.ZodType<OptionType['filterable']>;
  created_at: z.ZodType<OptionType['created_at']>;
  updated_at: z.ZodType<OptionType['updated_at']>;
  option_values: z.ZodOptional<z.ZodType<Exclude<OptionType['option_values'], undefined>>>;
}>;

export type { OptionType };
