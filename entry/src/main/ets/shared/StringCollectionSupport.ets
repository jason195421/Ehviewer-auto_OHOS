export function sortedStringKey(values: string[]): string {
  return values.slice().sort().join('|');
}

export function toggleStringValue(values: string[], value: string): string[] {
  const next = values.slice();
  const index = next.indexOf(value);
  if (index >= 0) {
    next.splice(index, 1);
  } else {
    next.push(value);
  }
  return next;
}
