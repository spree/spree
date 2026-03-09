// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const LocaleSchema = z.object({
  code: z.string(),
  name: z.string(),
});

export type Locale = z.infer<typeof LocaleSchema>;
