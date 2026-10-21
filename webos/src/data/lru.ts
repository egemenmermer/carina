// Small least-recently-used cache (insertion-ordered Map; get() refreshes).

export class Lru<T> {
  private map = new Map<string, T>();
  constructor(private max: number) {}

  get(k: string): T | undefined {
    const v = this.map.get(k);
    if (v !== undefined) {
      this.map.delete(k);
      this.map.set(k, v);
    }
    return v;
  }

  /** Lookup without refreshing the entry's recency. */
  peek(k: string): T | undefined {
    return this.map.get(k);
  }

  has(k: string): boolean {
    return this.map.has(k);
  }

  set(k: string, v: T): void {
    this.map.delete(k);
    this.map.set(k, v);
    while (this.map.size > this.max) {
      const oldest = this.map.keys().next().value as string;
      this.map.delete(oldest);
    }
  }

  delete(k: string): void {
    this.map.delete(k);
  }

  /** Drops every entry whose key matches [pred]. */
  deleteWhere(pred: (k: string) => boolean): void {
    const dead: string[] = [];
    this.map.forEach((_v, k) => {
      if (pred(k)) dead.push(k);
    });
    for (const k of dead) this.map.delete(k);
  }

  clear(): void {
    this.map.clear();
  }

  get size(): number {
    return this.map.size;
  }
}
