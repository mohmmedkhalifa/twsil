import { UserRole } from './database/entities/user.entity';

declare global {
  namespace Express {
    interface Request {
      user?: { id: string; role: UserRole; phone: string };
    }
  }
}

export {};