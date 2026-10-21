// Limits concurrent poster / logo downloads and lets off-screen images give
// their memory back. A grid scroll can create dozens of <img> per second; on a
// 1.5 GB TV an unbounded burst of decodes is what runs the app out of memory.
//
// Requests are served newest first: the most recently created images are the
// ones on screen, older queued ones have usually scrolled away already.

/** The slice of HTMLImageElement the gate touches (lets tests use plain objects). */
export interface ImgLike {
  src: string;
  onload: ((e?: unknown) => void) | null;
  onerror: ((e?: unknown) => void) | null;
}

/** 1x1 transparent GIF: replaces the source of released images so the decoded bitmap can be freed. */
export const BLANK = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';

export class ImageGate {
  private queue: { el: ImgLike; src: string }[] = [];
  private active: ImgLike[] = [];

  constructor(private limit = 4) {}

  get pending(): number {
    return this.queue.length;
  }

  get loading(): number {
    return this.active.length;
  }

  /** Loads [src] into [el] as soon as a slot is free. */
  request(el: ImgLike, src: string): void {
    this.queue.push({ el, src });
    this.pump();
  }

  /** Cancels a queued request or stops a running one and clears the element's source. */
  release(el: ImgLike): void {
    for (let i = this.queue.length - 1; i >= 0; i--) {
      if (this.queue[i].el === el) {
        this.queue.splice(i, 1);
        return;
      }
    }
    el.onload = null;
    el.onerror = null;
    const a = this.active.indexOf(el);
    if (a >= 0) {
      this.active.splice(a, 1);
      el.src = BLANK;
      this.pump();
    } else if (el.src && el.src !== BLANK) el.src = BLANK;
  }

  private pump(): void {
    while (this.active.length < this.limit && this.queue.length) {
      const job = this.queue.pop() as { el: ImgLike; src: string };
      const el = job.el;
      this.active.push(el);
      const prevLoad = el.onload;
      const prevError = el.onerror;
      const done = (): void => {
        const i = this.active.indexOf(el);
        if (i < 0) return; // released meanwhile
        this.active.splice(i, 1);
        this.pump();
      };
      el.onload = (e) => {
        done();
        if (prevLoad) prevLoad(e);
      };
      el.onerror = (e) => {
        done();
        if (prevError) prevError(e);
      };
      el.src = job.src;
    }
  }
}

export const imageGate = new ImageGate(4);
