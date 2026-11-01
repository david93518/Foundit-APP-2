import { ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** 沒有 Authorization 時當成訪客；有帶 token 但無效時仍拒絕。 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<{ headers: { authorization?: string } }>();
    if (!request.headers.authorization) return true;
    return super.canActivate(context);
  }

  handleRequest<T>(err: unknown, user: T): T {
    if (err) throw err;
    if (!user) throw new UnauthorizedException('登入已失效');
    return user;
  }
}
