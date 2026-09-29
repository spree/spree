// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
  active: z.boolean(),
});

export type Reason = z.infer<typeof ReasonSchema>;
