/**
 * Converts a unit to a size string
 * @param {number | undefined} unit 
 * @returns {string | undefined}
 */
export function unitToSize(unit) {
  if (typeof unit === "number") return `${unit}em`;
  return undefined;
}
