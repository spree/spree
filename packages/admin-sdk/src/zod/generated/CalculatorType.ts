// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CalculatorTypeSchema = z.object({
  type: z.string(),
  name: z.string(),
  schema: z.any(),
});

export type CalculatorType = z.infer<typeof CalculatorTypeSchema>;
