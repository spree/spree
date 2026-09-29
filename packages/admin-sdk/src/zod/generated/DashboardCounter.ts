// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DashboardCounterSchema = z.object({
  key: z.string(),
  value: z.number(),
  link: z.object({ resource: z.string(), filters: z.array(z.object({ field: z.string(), operator: z.string(), value: z.string() })) }).nullable(),
  nav: z.string().nullable(),
});

export type DashboardCounter = z.infer<typeof DashboardCounterSchema>;
