import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../common/entities/user.entity';
import { readJwtSecret } from './jwt-secret';
import { AccessTokenPayload, assertActiveSession } from './session';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: readJwtSecret(config),
      algorithms: ['HS256'],
    });
  }

  async validate(payload: AccessTokenPayload): Promise<User> {
    if (!payload?.sub) throw new UnauthorizedException('登入已失效');
    const user = await this.userRepo.findOne({ where: { id: payload.sub } });
    return assertActiveSession(user, payload.tv);
  }
}
