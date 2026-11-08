// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type OptionValue from '../../types/generated/OptionValue';
import { CustomFieldSchema } from './CustomField';
import { OptionTypeSchema } from './OptionType';

export const OptionValueSchema = z.object({
  id: z.string(),
  option_type_id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  color_code: z.string().nullable(),
  option_type_name: z.string(),
  option_type_label: z.string(),
  image_url: z.string().nullable(),
  custom_fields: z.array(CustomFieldSchema).optional(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  get option_type() { return OptionTypeSchema.optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<OptionValue['id']>;
  option_type_id: z.ZodType<OptionValue['option_type_id']>;
  name: z.ZodType<OptionValue['name']>;
  label: z.ZodType<OptionValue['label']>;
  position: z.ZodType<OptionValue['position']>;
  color_code: z.ZodType<OptionValue['color_code']>;
  option_type_name: z.ZodType<OptionValue['option_type_name']>;
  option_type_label: z.ZodType<OptionValue['option_type_label']>;
  image_url: z.ZodType<OptionValue['image_url']>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<OptionValue['custom_fields'], undefined>>>;
  metadata: z.ZodType<OptionValue['metadata']>;
  created_at: z.ZodType<OptionValue['created_at']>;
  updated_at: z.ZodType<OptionValue['updated_at']>;
  option_type: z.ZodOptional<z.ZodType<Exclude<OptionValue['option_type'], undefined>>>;
}>;

export type { OptionValue };
