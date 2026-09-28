import { Router } from 'express';
import { listUsers } from '../controllers/users.controller.js';
import { requireAuth } from '../middleware/auth.js';

export const usersRouter = Router();

usersRouter.get('/', requireAuth, listUsers);
