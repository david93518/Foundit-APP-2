import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { User } from '../entities/user.entity';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const user = context.switchToHttp().getRequest<{ user?: User }>().user;
    if (!user || user.role !== 'admin' || user.status !== 'active') {
      throw new ForbiddenException('需要管理員權限');
    }
    return true;
  }
}
