import { toPublicProfile } from './public-profile';
import { User } from '../common/entities/user.entity';

describe('toPublicProfile', () => {
  it('omits phone, email and authentication identifiers', () => {
    const profile = toPublicProfile({
      id: 'u1',
      name: '小明',
      avatarUrl: 'https://example.com/a.jpg',
      phone: '0912345678',
      email: 'a@example.com',
      googleSub: 'sub',
      fcmToken: 'token',
    } as User);
    expect(profile).toEqual({
      id: 'u1',
      name: '小明',
      avatar_url: 'https://example.com/a.jpg',
    });
    expect(JSON.stringify(profile)).not.toMatch(/0912|email|google|fcm|token/);
  });
});
