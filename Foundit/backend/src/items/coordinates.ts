/** 0,0 是未選點的假座標，不當成真實位置。 */
export function normalizeCoordinates(
  latitude?: number | null,
  longitude?: number | null,
): { latitude: number; longitude: number } | null {
  if (latitude == null || longitude == null) return null;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
  if (latitude === 0 && longitude === 0) return null;
  return { latitude, longitude };
}
