export class AsyncRequestGate {
  private generation: number = 0;

  begin(): number {
    this.generation++;
    return this.generation;
  }

  snapshot(): number {
    return this.generation;
  }

  isCurrent(generation: number): boolean {
    return generation === this.generation;
  }
}
