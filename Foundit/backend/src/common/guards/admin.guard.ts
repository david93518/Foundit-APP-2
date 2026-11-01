import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { User } from '../entities/user.entity';
import { isAdminUser } from '../admin-access';

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private readonly db: DataSource) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const user = context.switchToHttp().getRequest<{ user?: User }>().user;
    if (!user || user.status !== 'active' || !(await isAdminUser(this.db, user))) {
      throw new ForbiddenException('需要管理員權限');
    }
    return true;
  }
}
