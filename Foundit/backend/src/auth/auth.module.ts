import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { OtpService } from './otp.service';
import { User } from '../common/entities/user.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { AdminAction } from '../common/entities/admin-action.entity';
import { ChatsModule } from '../chats/chats.module';
import { readJwtExpiresIn, readJwtSecret } from './jwt-secret';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserPoints, AdminAction]),
    PassportModule,
    ChatsModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (config: ConfigService) => ({
        secret: readJwtSecret(config),
        signOptions: { expiresIn: readJwtExpiresIn(config) as any, algorithm: 'HS256' },
        verifyOptions: { algorithms: ['HS256'] },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, OtpService],
  exports: [AuthService, OtpService],
})
export class AuthModule {}
