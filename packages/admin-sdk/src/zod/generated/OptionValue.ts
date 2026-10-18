// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type OptionValue from '../../types/generated/OptionValue';
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
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  get option_type() { return OptionTypeSchema.optional(); },
}) as unknown as z.ZodObject<{ [K in keyof OptionValue]-?: z.ZodType<OptionValue[K]> }>;

export type { OptionValue };
