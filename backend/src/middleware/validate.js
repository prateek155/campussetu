// backend/src/middleware/validate.js
const Joi = require('joi');

/**
 * Returns an Express middleware that validates req.body against a Joi schema.
 * Sends 400 on failure.
 */
const validate = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.body, { abortEarly: false, stripUnknown: true });
  if (error) {
    return res.status(400).json({
      error: 'Validation failed',
      details: error.details.map((d) => d.message),
    });
  }
  req.body = value;
  next();
};

// ── Schemas ───────────────────────────────────────────────
const schemas = {
  updateProfile: Joi.object({
    name: Joi.string().min(2).max(100),
    college: Joi.string().max(200),
    state: Joi.string().max(100),
    city: Joi.string().max(100),
    course: Joi.string().max(50),
    branch: Joi.string().max(100),
    year_of_study: Joi.number().integer().min(1).max(7),
    bio: Joi.string().max(300).allow('', null),
    skills: Joi.array().items(Joi.string().max(50)).max(20),
    profile_complete: Joi.boolean(),
    photo_url: Joi.string().max(1000).allow('', null),
  }),

  createPost: Joi.object({
    content: Joi.string().min(1).max(2000).required(),
    image_url: Joi.string().uri().allow(null),
  }),

  createProduct: Joi.object({
    title: Joi.string().min(2).max(200).required(),
    description: Joi.string().max(1000).required(),
    price: Joi.number().min(0).required(),
    category: Joi.string().valid('Books', 'Electronics', 'Services', 'Clothing', 'Other').required(),
  }),

  createTshare: Joi.object({
    content: Joi.string().min(1).max(5000).required(),
    language: Joi.string().max(30).default('text'),
  }),
};

module.exports = { validate, schemas };
