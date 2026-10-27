import { campusForCoordinates } from './campus';
describe('NCKU scope', () => {
  it('includes NCKU and leaves other Taiwan cities in the nationwide feed', () => {
    expect(campusForCoordinates(22.998, 120.22)).toBe('ncku');
    expect(campusForCoordinates(25.033, 121.565)).toBe('');
    expect(campusForCoordinates(22.63, 120.3)).toBe('');
    expect(campusForCoordinates(0, 0)).toBe('');
    expect(campusForCoordinates(null, null)).toBe('');
  });
});
