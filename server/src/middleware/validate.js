import { HttpError } from './error.js';

export function validate(schema) {
  return (req, res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return next(
        new HttpError(
          400,
          'Validation failed',
          result.error.issues.map((i) => ({ field: i.path.join('.'), message: i.message })),
        ),
      );
    }
    req.body = result.data;
    next();
  };
}
