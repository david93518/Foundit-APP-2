import { User } from '../common/entities/user.entity';

/** 公開名片：不含電話、email、登入識別與推播 token。 */
export function toPublicProfile(user: Pick<User, 'id' | 'name' | 'avatarUrl'>): Record<string, unknown> {
  return {
    id: user.id,
    name: user.name ?? '',
    avatar_url: user.avatarUrl ?? '',
  };
}
